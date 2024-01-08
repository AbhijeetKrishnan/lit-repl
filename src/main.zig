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
        try stdout.writer().print("You entered: \"{s}\"\n", .{input});
        if (std.mem.eql(u8, input, "exit")) {
            is_exit = true;
            try stdout.writer().print("Exiting...\n", .{});
            continue;
        }
    }
}
