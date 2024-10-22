const std = @import("std");

const _card = @import("card.zig");
const Card = _card.Card;
const Suit = _card.Suit;
const Rank = _card.Rank;
const Half = _card.Half;
const halfSuitExists = _card.halfSuitExists;
const parse_cards_list = _card.parse_cards_list;

const _player = @import("player.zig");
const Player = _player.Player;
const PlayerCount = _player.PlayerCount;

const expect = std.testing.expect;

/// A record of a game actions
pub const HistoryRecord = struct {
    asker: *Player,
    askee: *Player,
    card: Card,
    success: bool,

    pub fn format(
        self: HistoryRecord,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;

        try writer.print(
            "Player {d} {s} asked Player {d} for card {any}",
            .{
                self.asker.id,
                if (self.success) "successfully" else "unsucessfully",
                self.askee.id,
                self.card,
            },
        );
    }

    test "format a history record" {
        std.debug.print("TODO: implement\n", .{});
        unreachable;
    }

    pub fn init(
        asker: *Player,
        askee: *Player,
        card: Card,
        success: bool,
    ) HistoryRecord {
        return HistoryRecord{
            .asker = asker,
            .askee = askee,
            .card = card,
            .success = success,
        };
    }
};

pub const GameError = error{
    PlayerIndexOutOfBounds,
    AskingSelfTeam,
    AskingFromEmpty,
    HalfSuitAbsent,
    PartialHalfSetClaimed,
    MalformedClaim,
    CurrentPlayerMustClaim,
    NoValidPlayers,
};

pub const ClaimOutcome = enum(u8) {
    Success,
    Partial,
    Failure,
};

pub const Game = struct {
    players: std.ArrayList(Player),
    num_players: PlayerCount = PlayerCount.SIX,
    odd_sets: u8 = 0, // count of odd team sets
    even_sets: u8 = 0, // count of even team sets
    current_player: *Player, // current player
    history: std.ArrayList(HistoryRecord), // history of game actions

    pub fn format(
        self: Game,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;

        for (self.players.items) |player| {
            try writer.print("{any}\n", .{player});
        }
        try writer.print("Num Players: {d}\n", .{@intFromEnum(self.num_players)});
        try writer.print("Odd Sets: {d}\n", .{self.odd_sets});
        try writer.print("Even Sets: {d}\n", .{self.even_sets});
        try writer.print("Current Player: {d}\n", .{self.current_player.id});
    }

    test "format a game" {
        std.debug.print("TODO: implement\n", .{});
        unreachable;
    }

    /// Initialize a new game
    pub fn init(
        allocator: std.mem.Allocator,
        num_players: PlayerCount,
    ) !Game {
        var game: Game = undefined;
        game.num_players = num_players;
        game.players = try Player.initPlayers(allocator, num_players);
        game.odd_sets = 0;
        game.even_sets = 0;
        game.current_player = &game.players.items[0]; // game starts with player 0
        game.history = std.ArrayList(HistoryRecord).init(allocator);
        return game;
    }

    pub fn deinit(self: *Game) !void {
        for (self.players.items) |player| {
            player.hand.deinit();
        }
        self.players.deinit();
        self.history.deinit();
    }

    test "display a game" {
        std.debug.print("TODO: implement\n", .{});
        unreachable;
    }

    /// Get player given player ID // TODO: get player by name/alias
    pub fn getPlayer(self: *const Game, player_id: u8) !*Player {
        if (player_id >= self.players.items.len or player_id < 0) {
            return GameError.PlayerIndexOutOfBounds;
        }
        return &self.players.items[player_id];
    }

    test "get player" {
        const allocator = std.testing.allocator;
        var game: Game = try Game.init(
            allocator,
            PlayerCount.SIX,
        );
        const player = try game.getPlayer(0);
        std.debug.print("{any}\n", .{player});
        try expect(player.id == 0);
        try expect(player.team == false);
        try expect(player.hand.items.len == 8);
        try expect(player.possibilities.len == 48);
        defer game.deinit() catch |err| {
            std.debug.print("Error: {any}\n", .{err});
        };
    }

    /// Ask a player for a card
    /// - Returns:
    ///     true if the card was found and performs the transfer between players
    ///     false if the card was not found and passes the turn to the asked player
    pub fn ask(
        self: *Game,
        asked_player: *Player,
        asked_card: Card,
    ) !bool {
        var asking_player = self.current_player;
        if (!(asking_player.team != asked_player.team))
            return GameError.AskingSelfTeam;
        if (asked_player.hand.items.len <= 0)
            return GameError.AskingFromEmpty;
        if (!halfSuitExists(
            asking_player.hand.items,
            asked_card,
        ))
            return GameError.HalfSuitAbsent;
        var found: bool = false;
        var found_idx: usize = undefined;
        for (0..asked_player.hand.items.len) |i| {
            if (std.meta.eql(asked_player.hand.items[i], asked_card)) {
                found = true;
                found_idx = i;
                break;
            }
        }
        if (found) {
            const found_card = asked_player.hand.swapRemove(found_idx);
            try asking_player.hand.append(found_card);
        } else {
            self.current_player = asked_player;
        }
        try self.history.append(HistoryRecord.init(
            asking_player,
            asked_player,
            asked_card,
            found,
        ));
        return found;
    }

    test "ask" {
        std.debug.print("TODO: implement\n", .{});
        unreachable;
    }

    /// Helper function to build a list of claims given a list of string-based claims from a player
    pub fn build_claims_list(
        self: *const Game,
        allocator: std.mem.Allocator,
        claiming_player: *const Player,
        claims_strs: []const []const u8,
    ) !std.ArrayList(std.ArrayList(Card)) {
        var claims_list = try std.ArrayList(std.ArrayList(Card)).initCapacity(
            allocator,
            @intFromEnum(self.num_players) / 2,
        );
        for (claims_list.capacity) |_| {
            try claims_list.append(undefined);
        }
        for (claims_strs) |item| {
            // check if claim string starts with a player ID followed by `=` and a list of cards
            if (item.len < 2) {
                return GameError.MalformedClaim;
            }
            var player_id: usize = undefined;
            var card_list: std.ArrayList(Card) = undefined;
            if (item[1] == '=') {
                // '=' present, treat previous digit as player ID and subsequent string as list of comma-separated cards
                player_id = item[0] - '0';
                card_list = try parse_cards_list(allocator, item[2..]);
            } else {
                // '=' not present, player ID is that of claiming player, and entire string is list of comma-separated
                // cards
                player_id = claiming_player.id;
                card_list = try parse_cards_list(allocator, item);
            }
            if (player_id < 0 or player_id >= @intFromEnum(self.num_players)) {
                defer card_list.deinit();
                defer claims_list.deinit();
                return GameError.PlayerIndexOutOfBounds;
            } else if (player_id % 2 != @intFromBool(claiming_player.team)) {
                defer card_list.deinit();
                defer claims_list.deinit();
                return GameError.MalformedClaim;
            }
            claims_list.items[player_id / 2] = card_list;
        }
        return claims_list;
    }

    test "build claims list" {
        try expect(@intFromEnum(PlayerCount.SIX) == 6);
        const allocator = std.testing.allocator;
        const game = Game{
            .players = undefined,
            .num_players = PlayerCount.SIX,
            .odd_sets = 0,
            .even_sets = 0,
            .current_player = undefined,
            .history = undefined,
        };
        const player = Player{
            .id = 0,
            .team = false,
            .hand = undefined,
            .possibilities = undefined,
        };
        const claims_strs = [_][]const u8{
            "4=2C, 3D, 4H,5S ",
            "2C, 3D,4H, 5S",
            "2=3D,4H, 5S",
        };
        const claims_list = try game.build_claims_list(
            allocator,
            &player,
            &claims_strs,
        );
        defer claims_list.deinit();
        for (claims_list.items) |claim| {
            std.debug.print("{any}\n", .{claim});
            defer claim.deinit();
        }
    }

    /// Check whether the claim for a suit is valid
    pub fn check_claim(
        self: *const Game,
        claiming_player: *const Player,
        half: Half,
        suit: Suit,
        claims: std.ArrayList(std.ArrayList(Card)),
    ) !ClaimOutcome {
        if (claiming_player.id != self.current_player.id) {
            return GameError.CurrentPlayerMustClaim;
        }
        var half_set: [6]bool = [_]bool{false} ** 6;
        const offset: u8 = if (half == Half.Low) 0 else 6;

        // iterate over each player of team
        var all_claims_match: bool = true;
        var index: u8 = 0;
        for (claims.items) |claim| {
            const player_idx = index * 2 + @intFromBool(claiming_player.team);
            const player = &self.players.items[player_idx];

            // each card in the claim must be in the player's hand
            for (claim.items) |card| {
                // check that half and suit lines up with claim
                if (!card.in_half_suit(half, suit)) {
                    all_claims_match = false;
                }

                var found: bool = false;
                for (player.hand.items) |hand_card| {
                    if (std.meta.eql(hand_card, card)) {
                        found = true;
                        const rank_idx: u8 = @intFromEnum(card.rank) - offset;
                        half_set[rank_idx] = true;
                        break;
                    }
                }
                if (!found) {
                    // TODO: better way of communicating why claim failed?
                    all_claims_match = false;
                }
            }
            index += 1;
        }

        // check that the half set is complete
        var half_set_complete: bool = true;
        for (half_set) |card| {
            if (!card) {
                // TODO: better way of communicating why claim failed?
                half_set_complete = false;
            }
        }

        if (all_claims_match and half_set_complete) {
            return ClaimOutcome.Success;
        } else if (half_set_complete) {
            return ClaimOutcome.Partial;
        } else {
            return ClaimOutcome.Failure;
        }
    }

    test "check claim" {
        std.debug.print("TODO: implement\n", .{});
        unreachable;
    }

    /// Given a claim, execute it
    pub fn execute_claim(
        self: *Game,
        claiming_player: *Player,
        half: Half,
        suit: Suit,
        outcome: ClaimOutcome,
    ) !void {
        // for each player, remove cards of the claimed set from their hand
        for (self.players.items) |*player| {
            if (player.team != claiming_player.team) {
                continue;
            }
            for (0..player.hand.items.len) |card_idx| {
                const card = player.hand.items[card_idx];
                if (card.in_half_suit(half, suit)) {
                    _ = player.hand.swapRemove(card_idx);
                }
            }
        }

        if (outcome == ClaimOutcome.Success) { // if claim was successful, award team a point
            // award the claiming team a point
            if (claiming_player.team) {
                self.odd_sets += 1;
            } else {
                self.even_sets += 1;
            }
        } else if (outcome == ClaimOutcome.Failure) { // if claim was unsuccessful, award other team a point
            // award the other team a point
            if (claiming_player.team) {
                self.even_sets += 1;
            } else {
                self.odd_sets += 1;
            }
        }
        // if claim was partially successful (all cards of half set present, but wrong distribution claimed), do nothing
    }

    test "execute claim" {
        std.debug.print("TODO: implement\n", .{});
        unreachable;
    }

    /// Determine turn after a claim
    pub fn next_turn(self: *Game) !void {
        // if possible to continue, turn stays with valid player on same team
        // assume turn stays with same player if possible, otherwise moves to next highest ID player on team until
        // a player with cards is found
        for (0..(@intFromEnum(self.num_players) / 2)) |_| {
            self.current_player = &self.players.items[(self.current_player.id + 2) % @intFromEnum(self.num_players)];
            if (self.current_player.hand.items.len > 0) {
                return;
            }
        }

        // if no players with cards are found, turn goes to a valid player on the other team
        self.current_player = &self.players.items[(self.current_player.id + 1) % @intFromEnum(self.num_players)];
        for (0..(@intFromEnum(self.num_players) / 2)) |_| {
            self.current_player = &self.players.items[(self.current_player.id + 1) % @intFromEnum(self.num_players)];
            if (self.current_player.hand.items.len > 0) {
                return;
            }
        }

        // if no players with cards are found, raise exception
        return GameError.NoValidPlayers;
    }

    test "next turn" {
        std.debug.print("TODO: implement\n", .{});
        unreachable;
    }
};
