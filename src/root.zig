const std = @import("std");

pub fn getPackageInfo(buffer: []u8, package_name: []const u8) !void {
    const cwd = std.fs.cwd();
    var registry = try cwd.openDir("registry", .{});
    defer registry.close();

    const name = try std.mem.concat(std.heap.page_allocator, u8, &[_][]const u8{package_name, ".zon"});
    var package_info = try registry.openFile(name, .{});
    defer package_info.close();

    var reader = package_info.reader(buffer);
    const reader_interface = &reader.interface;
    _ = try reader_interface.take(try reader.getSize());
}
