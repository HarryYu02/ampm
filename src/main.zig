const lib = @import("ampm");
const builtin = @import("builtin");
const std = @import("std");
const process = std.process;
const mem = std.mem;

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
        },
    }

    var command: Command = undefined;

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

    switch (command) {
        .install => {
            const package_arg = args_iter.next();
            if (package_arg == null) {
                std.debug.print("No package provided.\n", .{});
                return;
            }
            lib.install(package_arg.?) catch |err| {
                std.debug.print("Error installing package: {any}\n", .{err});
                return;
            };
        },
        .uninstall => {
            const package_arg = args_iter.next();
            if (package_arg == null) {
                std.debug.print("No package provided.\n", .{});
                return;
            }
            std.debug.print("Not implemented\n", .{});
        },
    }
}
