const std = @import("std");
const lit = @import("lit.zig");

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

fn splitCommand(input: []const u8) !std.ArrayList([]const u8) {
    var splits = std.mem.split(u8, input, " ");
    var heap_allocator = std.heap.page_allocator;
    var splitList: std.ArrayList([]const u8) = std.ArrayList([]const u8).init(heap_allocator);
    while (splits.next()) |chunk| {
        try splitList.append(chunk);
    }
    return splitList;
}

test "split a command" {
    var input = "claim ah,kh,qh 3=jh 5=9h,10h";
    var list: std.ArrayList([]const u8) = try splitCommand(input);
    defer list.deinit();
    try std.testing.expect(list.items.len == 4);
    try std.testing.expect(std.mem.eql(u8, list.items[0], "claim"));
    try std.testing.expect(std.mem.eql(u8, list.items[1], "ah,kh,qh"));
    try std.testing.expect(std.mem.eql(u8, list.items[2], "3=jh"));
    try std.testing.expect(std.mem.eql(u8, list.items[3], "5=9h,10h"));
}

const HELP_TEXT =
    \\  help: print this help text
    \\  exit: exit the Infinite!Lit REPL
    \\  init: start a new game with 6 players
    \\  ask [player] [card]: ask a player for a card
    \\  last [n]: show the last n asks
    \\  show: show the current game state
    \\  claim <cardlist> [player]=<cardlist>: claim a set
    \\  end: terminate the game
;

pub fn main() !void {
    const stdin = std.io.getStdIn();
    const stdout = std.io.getStdOut();

    var is_exit: bool = false;
    var command_buffer: [1024]u8 = undefined;

    try stdout.writer().print("Welcome to the Infinite!Lit REPL v0.0.1.\n", .{});
    try stdout.writer().print("Type \"help\" for more information, \"init\" to start a new game, or \"exit\" to close the program.\n", .{});

    var currGame: ?lit.Game = null;

    while (!is_exit) {
        if (currGame) |game| {
            try stdout.writer().print("lit {}*> ", .{game.current_player.id});
        } else {
            try stdout.writer().print("lit> ", .{});
        }
        const input = (try nextLine(stdin.reader(), &command_buffer)).?;
        std.debug.print("You entered: \"{s}\"\n", .{input});

        var command_list = try splitCommand(input);
        std.debug.print("Command list length: {d}\n", .{command_list.items.len});
        var command = command_list.items[0];
        std.debug.print("Command: \"{s}\"\n", .{command});

        if (std.mem.eql(u8, command, "exit") or std.mem.eql(u8, command, "quit")) {
            is_exit = true;
            try stdout.writer().print("Exiting...\n", .{});
        } else if (std.mem.eql(u8, command, "help")) {
            try stdout.writer().print("{s}\n", .{HELP_TEXT});
        } else if (std.mem.eql(u8, command, "init") or std.mem.eql(u8, command, "start")) {
            if (currGame) |_| {
                try stdout.writer().print("A game is already in progress. Please \"end\" it before starting a new one.\n", .{});
                continue;
            } else {
                const num_players: lit.PlayerCount = switch (command_list.items.len) {
                    1 => lit.PlayerCount.SIX,
                    else => blk: {
                        const input_player_count = try std.fmt.parseInt(u8, command_list.items[1], 10);
                        break :blk try lit.PlayerCount.intToEnum(input_player_count);
                    },
                };
                currGame = try lit.Game.init(num_players);
                try stdout.writer().print("Initialized a new game with {d} players.\n", .{@intFromEnum(num_players)});
            }
        } else if (std.mem.eql(u8, command, "ask")) {
            var player_id = try std.fmt.parseInt(u8, command_list.items[1], 10);
            const card = try lit.Card.parseCard(command_list.items[2]);
            if (currGame) |*game| {
                std.debug.print("{} asking player {d} for card {}.\n", .{ game.current_player.id, player_id, card });
                var asked_player = game.getPlayer(player_id);
                const success = try game.ask(asked_player, card);
                if (success) {
                    try stdout.writer().print("Yes. Player {} receives card {} from Player {d}.\n", .{ game.current_player.id, card, asked_player.id });
                } else {
                    try stdout.writer().print("No. Turn passes to Player {d}\n", .{asked_player.id});
                }
            } else {
                try stdout.writer().print("No game is currently in progress.\n", .{});
            }
        } else if (std.mem.eql(u8, command, "last")) {
            try stdout.writer().print("Not implemented yet.\n", .{}); // TODO: implement
        } else if (std.mem.eql(u8, command, "show")) {
            try stdout.writer().print("{?}\n", .{currGame});
        } else if (std.mem.eql(u8, command, "claim")) {
            try stdout.writer().print("Not implemented yet.\n", .{}); // TODO: implement
        } else if (std.mem.eql(u8, command, "end")) {
            currGame = null;
        } else {
            try stdout.writer().print("Unknown command \"{s}\".\n", .{command});
        }
    }
}

test {
    std.testing.refAllDeclsRecursive(@This());
}
