const std = @import("std");

const REGISTRY = "registry";
const BIN = "bin";

pub const Package = struct {
    name: []const u8,
    url: []const u8,
};

pub fn getPackageInfo(package_name: []const u8) !Package {
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
    return package_zon;
}

test "basic get package" {
    const pack = try getPackageInfo("cowsay");
    try std.testing.expectEqualStrings(pack.url, "https://github.com/cowsay-org/cowsay/archive/refs/tags/v3.8.4.tar.gz");
}

fn extractPackage(package: Package, bin_dir: std.fs.Dir, file_name: []const u8) !void {
    var file = try bin_dir.openFile(file_name, .{});
    defer file.close();

    var file_read_buf: [1024]u8 = undefined;
    var reader = file.reader(&file_read_buf);
    const reader_interface = &reader.interface;

    try bin_dir.makeDir(package.name);
    var pack_dir = try bin_dir.openDir(package.name, .{});
    defer pack_dir.close();

    var decompress_buf: [std.compress.flate.max_window_len]u8 = undefined;
    var dcp: std.compress.flate.Decompress = .init(
        reader_interface,
        .gzip,
        &decompress_buf
    );
    const dcp_reader = &dcp.reader;

    std.tar.pipeToFileSystem(pack_dir, dcp_reader, .{
        .mode_mode = .ignore,
    }) catch |err| {
        std.debug.print("tar err: {any}\n", .{err});
        return err;
    };
}

pub fn fetchPackage(package: Package) !void {
    const allocator = std.heap.page_allocator;
    var client = std.http.Client {
        .allocator = allocator,
    };

    const cwd = std.fs.cwd();
    var bin = try cwd.openDir(BIN, .{});
    defer bin.close();

    const file_name = "temp.tar.gz";
    const file = try bin.createFile(file_name, .{});
    defer {
        file.close();
        bin.deleteFile(file_name) catch unreachable;
    }

    var file_buf: [1024]u8 = undefined;
    var writer = file.writer(&file_buf);
    const file_interface = &writer.interface;
    const response = try client.fetch(.{
        .method = .GET,
        .location = .{ .url = package.url },
        .response_writer = file_interface,
    });
    _ = try file_interface.flush();
    std.debug.print("Fetch package: {any}\n", .{response.status});

    try extractPackage(package, bin, file_name);
}
