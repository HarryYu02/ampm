const lib = @import("ampm");
const builtin = @import("builtin");
const std = @import("std");
const process = std.process;
const mem = std.mem;

const VERSION = "0.0.0";
const CONFIG = "config.zon";

const Command = enum {
    help,
    version,
    search,
    info,
    list,
    install,
    update,
    uninstall,
    reinstall,
};

fn parseCommand(command_arg: ?[]const u8) !Command {
    if (command_arg == null) {
        std.debug.print("No command provided.\n", .{});
        return Command.help;
    } else if (mem.eql(u8, command_arg.?, "install")) {
        return Command.install;
    } else if (mem.eql(u8, command_arg.?, "uninstall")) {
        return Command.uninstall;
    } else if (mem.eql(u8, command_arg.?, "reinstall")) {
        return Command.reinstall;
    } else if (mem.eql(u8, command_arg.?, "search")) {
        return Command.search;
    } else if (mem.eql(u8, command_arg.?, "info")) {
        return Command.info;
    } else if (mem.eql(u8, command_arg.?, "list")) {
        return Command.list;
    } else if (mem.eql(u8, command_arg.?, "update")) {
        return Command.update;
    } else if (mem.eql(u8, command_arg.?, "--version")) {
        return Command.version;
    } else {
        std.debug.print("Unknown command provided.\n", .{});
        return error.UnknownCommand;
    }
}

pub fn main() !void {
    var config: lib.Config = .{
        .root = undefined,
        .bin = undefined,
        .man = undefined,
        .cache = undefined,
        .registry = undefined,
        .source = undefined,
    };

    const os = builtin.target.os.tag;
    const arch = builtin.target.cpu.arch;

    switch (os) {
        .macos => {
            switch (arch) {
                .x86_64 => {
                    const root = "/usr/local/ampm";
                    config.root = root;
                    config.bin = "/usr/local/bin";
                    config.man = "/usr/local/share/man";
                    config.cache = root ++ "/cache";
                    config.registry = root ++ "/registry";
                    config.source = root ++ "/source";
                },
                else => {
                    std.debug.print("Architecture not supported.\n", .{});
                    return;
                },
            }
        },
        else => {
            std.debug.print("OS not supported.\n", .{});
            return;
        },
    }

    var args_iter = process.args();
    _ = args_iter.next();

    const command = try parseCommand(args_iter.next());

    switch (command) {
        .install => {
            const package_arg = args_iter.next();
            if (package_arg == null) {
                std.debug.print("No package provided.\n", .{});
                return;
            }
            lib.install(package_arg.?, config) catch |err| {
                std.debug.print("Error installing package: {any}\n", .{err});
                return;
            };
        },
        .reinstall => {
            const package_arg = args_iter.next();
            if (package_arg == null) {
                std.debug.print("No package provided.\n", .{});
                return;
            }
            lib.uninstall(package_arg.?, config) catch |err| {
                std.debug.print("Error uninstalling package: {any}\n", .{err});
                return;
            };
            lib.install(package_arg.?, config) catch |err| {
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
            lib.uninstall(package_arg.?, config) catch |err| {
                std.debug.print("Error uninstalling package: {any}\n", .{err});
                return;
            };
        },
        .version => {
            std.debug.print("ampm v{s}\n", .{VERSION});
        },
        .list => {
            lib.list(config) catch |err| {
                std.debug.print("Error listing packages: {any}\n", .{err});
                return;
            };
        },
        else => {
            std.debug.print("Command not implemented.\n", .{});
            return;
        },
    }
}
