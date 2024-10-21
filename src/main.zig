const std = @import("std");
const lit = @import("root.zig");

fn nextLine(reader: anytype, buffer: []u8) !?[]const u8 {
    // Ref.: https://zig.guide/standard-library/readers-and-writers
    const line = (try reader.readUntilDelimiterOrEof(
        buffer,
        '\n',
    )) orelse return null;
    // trim annoying windows-only carriage return character
    if (@import("builtin").os.tag == .windows) {
        return std.mem.trimRight(
            u8,
            line,
            "\r",
        );
    } else {
        return line;
    }
}

fn splitCommand(
    allocator: std.mem.Allocator,
    input: []const u8,
) !std.ArrayList([]const u8) {
    var splits = std.mem.splitSequence(
        u8,
        input,
        " ",
    );
    var split_list = std.ArrayList([]const u8).init(allocator);
    while (splits.next()) |chunk| {
        try split_list.append(chunk);
    }
    return split_list;
}

test "split a command" {
    const input = "claim ah,kh,qh 3=jh 5=9h,10h";
    const allocator = std.testing.allocator;
    var list: std.ArrayList([]const u8) = try splitCommand(allocator, input);
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
        try stdout.writer().print(
            "lit {}*> ",
            .{game.current_player.id},
        );
    } else {
        try stdout.writer().print("lit> ", .{});
    }
}

const WELCOME_TEXT =
    \\Welcome to the Infinite!Lit REPL v0.1.0.
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
    try stdout.writer().print(
        "{s}\n",
        .{HELP_TEXT},
    );
}

test "help" {
    std.debug.print("TODO: implement\n", {});
    unreachable;
}

fn init(
    allocator: std.mem.Allocator,
    curr_game: *?lit.Game,
    command_list: *std.ArrayList([]const u8),
) !void {
    const stdout = std.io.getStdOut();

    if (curr_game.*) |_| {
        try stdout.writer().print(
            "A game is already in progress. Please \"end\" it before starting a new one.\n",
            .{},
        );
    } else {
        const num_players: lit.PlayerCount = switch (command_list.items.len) {
            1 => lit.PlayerCount.SIX,
            else => blk: {
                const input_player_count = try std.fmt.parseInt(
                    u8,
                    command_list.items[1],
                    10,
                );
                break :blk try lit.PlayerCount.intToEnum(input_player_count);
            },
        };
        curr_game.* = try lit.Game.init(allocator, num_players);
        try stdout.writer().print(
            "Initialized a new game with {d} players.\n",
            .{
                @intFromEnum(num_players),
            },
        );
    }
}

fn ask(
    curr_game: *?lit.Game,
    command_list: *std.ArrayList([]const u8),
) !void {
    const stdout = std.io.getStdOut();

    const player_id = try std.fmt.parseInt(u8, command_list.items[1], 10);
    const card = try lit.Card.parseCard(command_list.items[2]);

    if (curr_game.*) |*game| {
        const args = .{ game.current_player.id, player_id, card };
        const ArgsType = @TypeOf(args);
        const args_type_info = @typeInfo(ArgsType);
        if (args_type_info != .Struct) {
            @compileError("expected tuple or struct argument, found " ++ @typeName(ArgsType));
        }
        std.debug.print("{d} asking player {d} for card {any}.\n", args);
        const asked_player = try game.getPlayer(player_id);
        const success = game.ask(asked_player, card) catch |err| {
            switch (err) {
                lit.GameError.AskingSelfTeam => {
                    try stdout.writer().print(
                        "Illegal ask: Asker ({}) and askee ({}) are on the same team.\n",
                        .{ player_id, asked_player.id },
                    );
                },
                lit.GameError.AskingFromEmpty => {
                    try stdout.writer().print(
                        "Illegal ask: Askee's ({}) hand is empty.\n",
                        .{asked_player.id},
                    );
                },
                lit.GameError.HalfSuitAbsent => {
                    try stdout.writer().print(
                        "Illegal ask: Asker ({}) does not possess card of same half-suit.\n",
                        .{player_id},
                    );
                },
                else => {
                    try stdout.writer().print(
                        "An error occurred: {}\n",
                        .{err},
                    );
                },
            }
            return;
        };
        if (success) {
            try stdout.writer().print(
                "Yes. Player {} receives card {} from Player {d}.\n",
                .{
                    game.current_player.id,
                    card,
                    asked_player.id,
                },
            );
        } else {
            try stdout.writer().print(
                "No. Turn passes to Player {d}.\n",
                .{asked_player.id},
            );
        }
    } else {
        try stdout.writer().print("{s}\n", .{NO_GAME_TEXT});
    }
}

test "ask" {
    std.debug.print("TODO: implement\n", {});
    unreachable;
}

/// View the last n asks.
fn last(curr_game: *?lit.Game, command_list: *std.ArrayList([]const u8)) !void {
    const stdout = std.io.getStdOut();

    if (curr_game.*) |*game| {
        var num_last: u8 = undefined;
        if (command_list.items.len >= 2) {
            num_last = try std.fmt.parseInt(u8, command_list.items[1], 10);
        } else {
            num_last = 3;
        }
        var i = game.history.items.len - 1;
        while (i + num_last >= game.history.items.len) {
            const history_record = game.history.items[i];
            try stdout.writer().print("{any}\n", .{history_record});
            if (i == 0) { // otherwise integer overflow error since i is unsigned
                break;
            }
            i -= 1;
        }
    } else {
        try stdout.writer().print("{s}\n", .{NO_GAME_TEXT});
    }
}

test "last" {
    std.debug.print("TODO: implement\n", {});
    unreachable;
}

fn claim(
    allocator: std.mem.Allocator,
    curr_game: *?lit.Game,
    command_list: *std.ArrayList([]const u8),
) !void {
    const stdout = std.io.getStdOut();

    if (curr_game.*) |*game| {
        const claims_list = try game.build_claims_list(
            allocator,
            game.current_player,
            command_list.items[1..],
        );
        var half: lit.Half = undefined;
        var suit: lit.Suit = undefined;
        var found: bool = false;

        // find the half-suit of the claim
        // assume it is the first in the list
        for (claims_list.items) |claim_list| {
            for (claim_list.items) |curr_claim| {
                half = curr_claim.get_half_suit();
                suit = curr_claim.suit;
                found = true;
                break;
            }
            if (found) {
                break;
            }
        }

        const outcome = try game.check_claim(
            game.current_player,
            half,
            suit,
            claims_list,
        );
        switch (outcome) {
            lit.ClaimOutcome.Success => {
                try stdout.writer().print(
                    "Claim successful. Awarding Team {d} the set...\n",
                    .{@intFromBool(game.current_player.team)},
                );
            },
            lit.ClaimOutcome.Failure => {
                try stdout.writer().print(
                    "Claim failed. Awarding Team {d} the set...\n",
                    .{
                        @intFromBool(!game.current_player.team),
                    },
                );
            },
            lit.ClaimOutcome.Partial => {
                try stdout.writer().print(
                    "Claim partially successful. No points awarded.\n",
                    .{},
                );
            },
        }
        try game.execute_claim(
            game.current_player,
            half,
            suit,
            outcome,
        );
        try game.next_turn();
    } else {
        try stdout.writer().print("{s}\n", .{NO_GAME_TEXT});
    }
}

test "claim" {
    std.debug.print("TODO: implement\n", {});
    unreachable;
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

test "end" {
    std.debug.print("TODO: implement\n", {});
    unreachable;
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
        const input = (try nextLine(
            stdin.reader(),
            &command_buffer,
        )).?;

        var command_list = try splitCommand(
            allocator,
            input,
        );
        defer command_list.deinit();
        const command = command_list.items[0];

        if (std.mem.eql(u8, command, "exit") or std.mem.eql(u8, command, "quit")) {
            // ask for confirmation if game is in progress
            if (curr_game != null) {
                try stdout.writer().print(
                    "A game is currently in progress. Are you sure you want to {s}? [y/N] ",
                    .{command},
                );
                const confirm = (try nextLine(
                    stdin.reader(),
                    &command_buffer,
                )).?;
                if (!std.mem.eql(u8, confirm, "y")) {
                    continue;
                } else {
                    try end(&curr_game);
                }
            }
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
            try claim(allocator, &curr_game, &command_list);
        } else if (std.mem.eql(u8, command, "end")) {
            try end(&curr_game);
        } else {
            try stdout.writer().print(
                "Unknown command \"{s}\". Please type \"help\" for a list of available commands.\n",
                .{command},
            );
        }
    }
}

test "main" {
    std.debug.print("TODO: implement\n", {});
    unreachable;
}

test {
    comptime {
        std.testing.refAllDeclsRecursive(@This());
    }
}
