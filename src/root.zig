//! libampm
const std = @import("std");

const REGISTRY = "registry";
const BIN = "bin";

pub const Config = struct {
    dir: []const u8,
};

const Compression = enum {
    raw,
    tar,
    tgz,
    zip,
};

pub const Package = struct {
    name: []const u8,
    url: []const u8,
};

fn installPackage() !void {
    std.debug.print("Installing package...\n", .{});
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
                        return str[start .. end];
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
    package: Package,
    bin_dir: std.fs.Dir,
    file: *std.fs.File,
    compression: Compression
) !void {
    std.debug.print("Extracting package...\n", .{});
    var file_read_buf: [1024]u8 = undefined;
    var reader = file.*.reader(&file_read_buf);
    const reader_interface = &reader.interface;

    try bin_dir.makeDir(package.name);
    var pack_dir = try bin_dir.openDir(package.name, .{});
    defer pack_dir.close();

    switch (compression) {
        .tgz => {
            var decompress_buf: [std.compress.flate.max_window_len]u8 = undefined;
            var decompressor: std.compress.flate.Decompress = .init(
                reader_interface,
                .gzip,
                &decompress_buf
            );
            const decompress_reader = &decompressor.reader;

            std.tar.pipeToFileSystem(pack_dir, decompress_reader, .{
                .mode_mode = .ignore,
            }) catch |err| {
                std.debug.print("Tar err: {any}\n", .{err});
                return err;
            };
        },
        else => {
            return error.PackageCompressionNotSupported;
        }
    }
}

fn fetchPackage(allocator: std.mem.Allocator, package: Package, file: *std.fs.File) !void {
    std.debug.print("Fetching package from: {s}\n", .{package.url});
    var client = std.http.Client {
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
    var registry = try cwd.openDir(REGISTRY, .{});
    defer registry.close();

    const allocator = std.heap.page_allocator;
    const name = try std.mem.concat(allocator, u8, &[_][]const u8{package_name, ".zon"});
    const package_str = try registry.readFileAllocOptions(allocator, name, 2048, null, std.mem.Alignment.@"1", 0);
    const package_zon = try std.zon.parse.fromSlice(
        Package,
        allocator,
        package_str,
        null,
        .{ .ignore_unknown_fields = true }
    );

    var bin = try cwd.openDir(BIN, .{});
    defer bin.close();

    const last_slash_idx = std.mem.lastIndexOf(u8, package_zon.url, "/");
    const file_name = package_zon.url[(last_slash_idx orelse 0) + 1 ..];
    var file = try bin.createFile(file_name, .{
        .read = true,
    });
    defer {
        file.close();
        bin.deleteFile(file_name) catch unreachable;
    }

    var compression: Compression = undefined;
    if (std.mem.endsWith(u8, file_name, ".tar.gz")) {
        compression = .tgz;
    } else {
        return error.PackageCompressionNotSupported;
    }

    try fetchPackage(allocator, package_zon, &file);
    try extractPackage(package_zon, bin, &file, compression);
    try installPackage();

    std.debug.print("Package installed!\n", .{});
}
