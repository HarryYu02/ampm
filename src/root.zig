//! libampm
const std = @import("std");

const BIN = "bin";
const CACHE = "cache";
const REGISTRY = "registry";
const SOURCE = "source";

pub const Config = struct {
    dir: []const u8,
};

const Compression = enum {
    tar,
    tgz,
};

const InstallEnv = enum {
    prefix,
    man,
};

const InstallArgTag = enum {
    str,
    env,
};

const InstallArg = union(InstallArgTag) {
    str: []const u8,
    env: InstallEnv,
};

pub const Package = struct {
    name: []const u8,
    desc: []const u8,
    homepage: []const u8,
    url: []const u8,
    license: []const u8,
    install: []const []const InstallArg,
};

fn linkPackage(bin_dir: std.fs.Dir, source_dir: std.fs.Dir, name: []const u8) !void {
    std.debug.print("Linking package...\n", .{});
    var path_buf: [1024]u8 = undefined;
    const link_path = try source_dir.realpath(name, &path_buf);
    try bin_dir.symLink(link_path, name, .{});
}

// zig fmt: off
fn buildInstallCommand(
    allocator: std.mem.Allocator,
    raw_command: []const InstallArg,
    install_env_map: std.hash_map.AutoHashMap(InstallEnv, []const u8)
) ![]const u8 {
// zig fmt: on
    var command: []u8 = "";
    for (raw_command) |arg| {
        switch (arg) {
            .str => |str_arg| {
                const new_command = try std.mem.concat(allocator, u8, &[_][]const u8{ command, str_arg });
                command = new_command;
            },
            .env => |env_arg| {
                const env_arg_str = install_env_map.get(env_arg);
                if (env_arg_str == null) {
                    return error.InstallArgNotFound;
                }
                const new_command = try std.mem.concat(allocator, u8, &[_][]const u8{ command, env_arg_str.? });
                command = new_command;
            },
        }
    }
    return command;
}

// zig fmt: off
fn installPackage(
    allocator: std.mem.Allocator,
    package: Package,
    install_env_map: std.hash_map.AutoHashMap(InstallEnv, []const u8)
) !void {
// zig fmt: on
    std.debug.print("Installing package...\n", .{});
    for (package.install) |raw_command| {
        const command_str = try buildInstallCommand(allocator, raw_command, install_env_map);
        const script = &[_][]const u8{ "sh", "-c", command_str };
        var child_process = std.process.Child.init(script, allocator);
        try child_process.spawn();
        const status = try child_process.wait();
        _ = status;
    }
}

fn isNumber(char: u8) bool {
    return char >= '0' and char <= '9';
}

/// Extract sem ver from str, return null if sem ver is not found.
/// "test-12.34.5" -> "12.34.5"
/// "foo-v1.2." -> null
fn extractSemVer(str: []const u8) ?[]const u8 {
    var start: u8 = 0;
    var end: u8 = 0;
    if (str.len < 5) return null;
    while (start < str.len - 4) : (start += 1) {
        if (isNumber(str[start])) {
            while (!isNumber(str[start])) {
                start += 1;
            }
            end = start;
            while (end < str.len and isNumber(str[end])) {
                end += 1;
            }
            if (end < str.len and str[end] == '.') {
                end += 1;
                while (end < str.len and isNumber(str[end])) {
                    end += 1;
                }
                if (end < str.len and str[end] == '.') {
                    end += 1;
                    while (end < str.len and isNumber(str[end])) {
                        end += 1;
                    }
                    if (isNumber(str[end - 1])) {
                        return str[start..end];
                    }
                } else {
                    start = end;
                    continue;
                }
            } else {
                start = end;
                continue;
            }
        }
    }
    return null;
}

test "extract sem ver" {
    try std.testing.expectEqualSlices(u8, "12.34.56", extractSemVer("test-12.34.56").?);
    try std.testing.expectEqualSlices(u8, "1.2.3", extractSemVer("1.2.3").?);
    try std.testing.expectEqualSlices(u8, "12.34.56", extractSemVer("test-12.34test-12.34.56").?);
    try std.testing.expectEqual(null, extractSemVer("test-12.34"));
    try std.testing.expectEqual(null, extractSemVer("test-12.34."));
}

fn extractPackage(
    dir: std.fs.Dir,
    file: *std.fs.File,
    compression: Compression,
) !void {
    std.debug.print("Extracting package...\n", .{});
    var file_read_buf: [1024]u8 = undefined;
    var reader = file.*.reader(&file_read_buf);
    const reader_interface = &reader.interface;

    switch (compression) {
        .tgz => {
            var decompress_buf: [std.compress.flate.max_window_len]u8 = undefined;
            var decompressor: std.compress.flate.Decompress = .init(reader_interface, .gzip, &decompress_buf);
            const decompress_reader = &decompressor.reader;

            std.tar.pipeToFileSystem(dir, decompress_reader, .{
                .mode_mode = .ignore,
                .strip_components = 1,
            }) catch |err| {
                std.debug.print("Tar err: {any}\n", .{err});
                return err;
            };
        },
        else => {
            return error.PackageCompressionNotSupported;
        },
    }
}

fn fetchPackage(allocator: std.mem.Allocator, package: Package, file: *std.fs.File) !void {
    std.debug.print("Fetching package from: {s}\n", .{package.url});
    var client = std.http.Client{
        .allocator = allocator,
    };

    var file_buf: [1024]u8 = undefined;
    var writer = file.*.writer(&file_buf);
    const file_interface = &writer.interface;
    const response = try client.fetch(.{
        .method = .GET,
        .location = .{ .url = package.url },
        .response_writer = file_interface,
    });
    _ = try file_interface.flush();
    if (response.status != std.http.Status.ok) {
        return error.FetchNotOk;
    }
}

/// Install a package by name
pub fn install(package_name: []const u8) !void {
    const cwd = std.fs.cwd();
    var root = try cwd.openDir("./", .{});
    defer root.close();

    var registry = try root.openDir(REGISTRY, .{});
    defer registry.close();
    const allocator = std.heap.page_allocator;

    const register_name = try std.mem.concat(allocator, u8, &[_][]const u8{ package_name, ".zon" });
    // zig fmt: off
    const package_str = try registry.readFileAllocOptions(
        allocator,
        register_name,
        2048,
        null,
        std.mem.Alignment.@"1", 0
    );
    const package_zon = try std.zon.parse.fromSlice(
        Package,
        allocator,
        package_str,
        null,
        .{ .ignore_unknown_fields = true }
    );
    // zig fmt: on

    var cache_dir = try root.openDir(CACHE, .{});
    defer cache_dir.close();

    const last_slash_idx = std.mem.lastIndexOf(u8, package_zon.url, "/");
    const compressed_file_name = package_zon.url[(last_slash_idx orelse 0) + 1 ..];
    var compressed_file = try cache_dir.createFile(compressed_file_name, .{
        .read = true,
    });
    defer {
        compressed_file.close();
        cache_dir.deleteFile(compressed_file_name) catch unreachable;
    }

    try fetchPackage(allocator, package_zon, &compressed_file);

    var compression: Compression = undefined;
    if (std.mem.endsWith(u8, compressed_file_name, ".tar.gz")) {
        compression = .tgz;
    } else {
        return error.PackageCompressionNotSupported;
    }

    try cache_dir.makeDir(package_zon.name);
    var cache_pack_dir = try cache_dir.openDir(package_zon.name, .{});
    defer {
        cache_pack_dir.close();
        cache_dir.deleteTree(package_zon.name) catch unreachable;
    }

    try extractPackage(cache_pack_dir, &compressed_file, compression);

    var source_dir = try root.openDir(SOURCE, .{});
    defer source_dir.close();
    try source_dir.makeDir(package_zon.name);
    var pack_dir = try source_dir.openDir(package_zon.name, .{});
    defer pack_dir.close();
    const semver = extractSemVer(compressed_file_name) orelse compressed_file_name;
    try pack_dir.makeDir(semver);
    var ver_dir = try pack_dir.openDir(semver, .{});
    defer ver_dir.close();

    var install_env_map = std.hash_map.AutoHashMap(InstallEnv, []const u8).init(allocator);
    defer install_env_map.deinit();

    var prefix_str: [1024]u8 = undefined;
    const prefix = try ver_dir.realpath("./", &prefix_str);
    try install_env_map.put(.prefix, prefix);
    const man = try std.mem.concat(allocator, u8, &[_][]const u8{ prefix, "/share/man" });
    try install_env_map.put(.man, man);

    try cache_pack_dir.setAsCwd();
    try installPackage(allocator, package_zon, install_env_map);

    try root.setAsCwd();
    var source_bin_dir = try ver_dir.openDir(BIN, .{});
    defer source_bin_dir.close();

    var bin_dir = try root.openDir(BIN, .{});
    defer bin_dir.close();

    try linkPackage(bin_dir, source_bin_dir, package_zon.name);

    std.debug.print("Package installed successfully!\n", .{});
}

/// Uninstall a package by name
pub fn uninstall(package_name: []const u8) !void {
    const cwd = std.fs.cwd();
    var root = try cwd.openDir("./", .{});
    defer root.close();

    var bin_dir = try root.openDir(BIN, .{});
    defer bin_dir.close();
    try bin_dir.deleteFile(package_name);

    std.debug.print("Package uninstalled successfully!\n", .{});
}
