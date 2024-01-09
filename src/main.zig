const std = @import("std");

fn nextLine(reader: anytype, buffer: []u8) !?[]const u8 {
    // Ref.: https://zig.guide/standard-library/readers-and-writers
    var line = (try reader.readUntilDelimiterOrEof(
        buffer,
        '\n',
    )) orelse return null;
    // trim annoying windows-only carriage return character
    if (@import("builtin").os.tag == .windows) {
        return std.mem.trimRight(u8, line, "\r");
    } else {
        return line;
    }
}

pub fn main() !void {
    const stdin = std.io.getStdIn();
    const stdout = std.io.getStdOut();

    var is_exit: bool = false;
    var command_buffer: [1024]u8 = undefined;

    try stdout.writer().print("Welcome to the Infinite!Lit REPL v0.0.1.\n", .{});
    try stdout.writer().print("Type \"help\" for more information, \"init\" to start a new game, or \"exit\" to close the program.\n", .{});

    while (!is_exit) {
        try stdout.writer().print("lit> ", .{});
        const input = (try nextLine(stdin.reader(), &command_buffer)).?;
        std.debug.print("You entered: \"{s}\"\n", .{input});

        var it = std.mem.split(u8, input, " ");
        var command = it.next() orelse return error.InvalidInput;
        std.debug.print("Command: \"{s}\"\n", .{command});

        if (std.mem.eql(u8, command, "exit") or std.mem.eql(u8, command, "quit")) {
            is_exit = true;
            try stdout.writer().print("Exiting...\n", .{});
        } else if (std.mem.eql(u8, command, "help")) {
            try stdout.writer().print("Help is not yet implemented.\n", .{});
        } else if (std.mem.eql(u8, command, "init")) {
            try stdout.writer().print("Init is not yet implemented.\n", .{});
        } else {
            try stdout.writer().print("Unknown command \"{s}\".\n", .{command});
        }
    }
}
