const std = @import("std");

pub fn getPackageInfo(package_name: []const u8) ![:0]const u8 {
    const cwd = std.fs.cwd();
    var registry = try cwd.openDir("registry", .{});
    defer registry.close();

    const allocator = std.heap.page_allocator;
    const name = try std.mem.concat(std.heap.page_allocator, u8, &[_][]const u8{package_name, ".zon"});
    return try registry.readFileAllocOptions(allocator, name, 1024, null, std.mem.Alignment.@"1", 0);
}
