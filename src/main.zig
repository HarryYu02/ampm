const lib = @import("ampm");
const builtin = @import("builtin");
const std = @import("std");
const process = std.process;
const mem = std.mem;

const PACKAGES_DIR = "./packages";
const BIN_DIR = "./bin";

const Command = enum {
    install,
    uninstall,
};

pub fn main() !void {
    switch (builtin.target.os.tag) {
        .macos => {},
        else => {
            std.debug.print("OS not supported.\n", .{});
            return;
        }
    }

    var command: Command = undefined;
    var package: []const u8 = undefined;

    var args_iter = process.args();
    _ = args_iter.next();
    const command_arg = args_iter.next();
    if (command_arg == null) {
        std.debug.print("No command provided.\n", .{});
        return;
    } else if (mem.eql(u8, command_arg.?, "install")) {
        command = Command.install;
    } else if (mem.eql(u8, command_arg.?, "uninstall")) {
        command = Command.uninstall;
    } else {
        std.debug.print("Unknown command provided.\n", .{});
        return;
    }

    // TODO: options

    const package_arg = args_iter.next();
    if (package_arg == null) {
        std.debug.print("No package provided.\n", .{});
        return;
    }
    package = package_arg.?;
    const package_str = lib.getPackageInfo(package) catch |err| {
        std.debug.print("Error fetching package info: {any}\n", .{err});
        return;
    };
    const package_zon = try std.zon.parse.fromSlice(
        struct {
            url: []const u8,
        },
        std.heap.page_allocator,
        package_str,
        null,
        .{ .ignore_unknown_fields = true });
    std.debug.print("zon: {s}\n", .{package_zon.url});
}
