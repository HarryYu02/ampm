const ampm = @import("ampm");
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
        .macos => {
            std.debug.print("All your {s} are belong to us.\n", .{"Mac"});
        },
        else => {
            std.debug.print("OS not supported.\n", .{});
            return;
        }
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
        std.debug.print("Install\n", .{});
    } else if (mem.eql(u8, command_arg.?, "uninstall")) {
        command = Command.uninstall;
        std.debug.print("Uninstall\n", .{});
    } else {
        std.debug.print("Unknown command provided.\n", .{});
        return;
    }
}
