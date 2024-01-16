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

fn splitCommand(allocator: std.mem.Allocator, input: []const u8) !std.ArrayList([]const u8) {
    var splits = std.mem.splitSequence(u8, input, " ");
    var split_list: std.ArrayList([]const u8) = std.ArrayList([]const u8).init(allocator);
    while (splits.next()) |chunk| {
        try split_list.append(chunk);
    }
    return split_list;
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

fn printPrompt(curr_game: ?lit.Game) !void {
    const stdout = std.io.getStdOut();
    if (curr_game) |game| {
        try stdout.writer().print("lit {}*> ", .{game.current_player.id});
    } else {
        try stdout.writer().print("lit> ", .{});
    }
}

const WELCOME_TEXT =
    \\Welcome to the Infinite!Lit REPL v0.0.1.
    \\Type "help" for more information, "init" to start a new game, or "exit" to close the program.
;

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

const EXIT_TEXT =
    \\Exiting...
;

const INVALID_COMMAND_TEXT =
    \\Unknown command "{s}".
;

const NO_GAME_TEXT =
    \\No game is currently in progress.
;

fn help() !void {
    const stdout = std.io.getStdOut();
    try stdout.writer().print("{s}\n", .{HELP_TEXT});
}

fn init(allocator: std.mem.Allocator, curr_game: *?lit.Game, command_list: *std.ArrayList([]const u8)) !void {
    const stdout = std.io.getStdOut();

    if (curr_game.*) |_| {
        try stdout.writer().print("A game is already in progress. Please \"end\" it before starting a new one.\n", .{});
    } else {
        const num_players: lit.PlayerCount = switch (command_list.items.len) {
            1 => lit.PlayerCount.SIX,
            else => blk: {
                const input_player_count = try std.fmt.parseInt(u8, command_list.items[1], 10);
                break :blk try lit.PlayerCount.intToEnum(input_player_count);
            },
        };
        curr_game.* = try lit.Game.init(allocator, num_players);
        try stdout.writer().print("Initialized a new game with {d} players.\n", .{@intFromEnum(num_players)});
    }
}

fn ask(curr_game: *?lit.Game, command_list: *std.ArrayList([]const u8)) !void {
    const stdout = std.io.getStdOut();

    var player_id = try std.fmt.parseInt(u8, command_list.items[1], 10);
    const card = try lit.Card.parseCard(command_list.items[2]);

    if (curr_game.*) |*game| {
        std.debug.print("{} asking player {d} for card {}.\n", .{ game.current_player.id, player_id, card });
        var asked_player = game.getPlayer(player_id);
        const success = try game.ask(asked_player, card);
        if (success) {
            try stdout.writer().print("Yes. Player {} receives card {} from Player {d}.\n", .{ game.current_player.id, card, asked_player.id });
        } else {
            try stdout.writer().print("No. Turn passes to Player {d}.\n", .{asked_player.id});
        }
    } else {
        try stdout.writer().print("{s}\n", .{NO_GAME_TEXT});
    }
}

fn last(curr_game: *?lit.Game, command_list: *std.ArrayList([]const u8)) !void {
    const stdout = std.io.getStdOut();

    if (curr_game.*) |*game| {
        _ = game;
        var num_last = try std.fmt.parseInt(u8, command_list.items[1], 10);
        _ = num_last;
        try stdout.writer().print("TODO: implement\n", .{});
    } else {
        try stdout.writer().print("{s}\n", .{NO_GAME_TEXT});
    }
}

fn claim(curr_game: *?lit.Game, command_list: *std.ArrayList([]const u8)) !void {
    _ = command_list;
    const stdout = std.io.getStdOut();

    if (curr_game.*) |*game| {
        _ = game;
        try stdout.writer().print("TODO: implement\n", .{});
    } else {
        try stdout.writer().print("{s}\n", .{NO_GAME_TEXT});
    }
}

fn end(curr_game: *?lit.Game) !void {
    const stdout = std.io.getStdOut();

    if (curr_game.*) |*game| {
        try game.deinit();
        curr_game.* = null;
        try stdout.writer().print("Game terminated.\n", .{});
    } else {
        try stdout.writer().print("{s}\n", .{NO_GAME_TEXT});
    }
}

pub fn main() !void {
    const stdin = std.io.getStdIn();
    const stdout = std.io.getStdOut();

    var curr_game: ?lit.Game = null;
    var is_exit: bool = false;
    var command_buffer: [1024]u8 = undefined;

    try stdout.writer().print("{s}\n", .{WELCOME_TEXT});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    while (!is_exit) {
        try printPrompt(curr_game);
        const input = (try nextLine(stdin.reader(), &command_buffer)).?;

        var command_list = try splitCommand(allocator, input);
        defer command_list.deinit();
        var command = command_list.items[0];

        if (std.mem.eql(u8, command, "exit") or std.mem.eql(u8, command, "quit")) {
            is_exit = true;
            try stdout.writer().print("{s}\n", .{EXIT_TEXT});
        } else if (std.mem.eql(u8, command, "help")) {
            try help();
        } else if (std.mem.eql(u8, command, "init") or std.mem.eql(u8, command, "start")) {
            try init(allocator, &curr_game, &command_list);
        } else if (std.mem.eql(u8, command, "ask")) {
            try ask(&curr_game, &command_list);
        } else if (std.mem.eql(u8, command, "last")) {
            try last(&curr_game, &command_list);
        } else if (std.mem.eql(u8, command, "show")) {
            try stdout.writer().print("{?}\n", .{curr_game});
        } else if (std.mem.eql(u8, command, "claim")) {
            try claim(&curr_game, &command_list);
        } else if (std.mem.eql(u8, command, "end")) {
            try end(&curr_game);
        } else {
            try stdout.writer().print("Unknown command \"{s}\". Please type \"help\" for a list of available commands.\n", .{command});
        }
    }
}

test {
    std.testing.refAllDeclsRecursive(@This());
}
