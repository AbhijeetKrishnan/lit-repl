const std = @import("std");
const expect = std.testing.expect;

const _card = @import("card.zig");
const Card = _card.Card;
const Possibility = _card.Possibility;
const generateDeck = _card.generateDeck;

pub const PlayerCount = enum(u8) {
    SIX = 6,
    EIGHT = 8,

    pub fn intToEnum(i: u8) !PlayerCount {
        switch (i) {
            6 => return PlayerCount.SIX,
            8 => return PlayerCount.EIGHT,
            else => return undefined,
        }
    }
};

/// Deal cards to each player randomly
fn dealCards(
    allocator: std.mem.Allocator,
    num_players: PlayerCount,
    seed: ?u64,
) !std.ArrayList(std.ArrayList(Card)) {
    var deck: [48]Card = comptime generateDeck();
    var true_seed: u64 = undefined;

    if (seed) |s| {
        true_seed = s;
    } else {
        try std.posix.getrandom(std.mem.asBytes(&true_seed));
    }

    var prng = std.rand.DefaultPrng.init(true_seed);
    const rand = &prng.random();

    rand.shuffle(Card, &deck);

    var hands = try std.ArrayList(std.ArrayList(Card)).initCapacity(
        allocator,
        @intFromEnum(num_players),
    );
    const hand_size: u8 = 48 / @intFromEnum(num_players);
    for (0..@intFromEnum(num_players)) |i| {
        var hand = std.ArrayList(Card).init(allocator);
        for (0..hand_size) |j| {
            try hand.append(deck[i * hand_size + j]);
        }
        try hands.append(hand);
    }
    return hands;
}

test "deal cards" {
    const allocator = std.testing.allocator;
    var hands: std.ArrayList(std.ArrayList(Card)) = try dealCards(
        allocator,
        PlayerCount.SIX,
        0,
    );

    std.debug.print("0: {any}\n", .{hands.items[0].items});
    std.debug.print("1: {any}\n", .{hands.items[1].items});
    std.debug.print("2: {any}\n", .{hands.items[2].items});
    std.debug.print("3: {any}\n", .{hands.items[3].items});
    std.debug.print("4: {any}\n", .{hands.items[4].items});
    std.debug.print("5: {any}\n", .{hands.items[5].items});

    try expect(hands.items.len == 6);
    for (hands.items) |hand| {
        try expect(hand.items.len == 8);
    }

    for (hands.items) |hand| {
        defer hand.deinit();
    }
    defer hands.deinit();
}

pub const Player = struct {
    id: usize, // player ID, used as index into players array
    team: bool, // false = even, true = odd
    hand: std.ArrayList(Card),
    possibilities: [48]Possibility, // 48 cards grouped into 8 sets of 6

    pub fn deinit(self: *const Player) !void {
        self.hand.deinit();
    }

    pub fn format(
        self: Player,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;

        try writer.print("ID: {}\n", .{self.id});
        try writer.print("Team: {}\n", .{self.team});
        try writer.print("Hand: {s}", .{self.hand.items});
        // try writer.print("Possibilities: {any}\n", .{self.possibilities});
    }

    test "display players" {
        std.debug.print("TODO: implement\n", {});
        unreachable;
    }

    /// Initialize the set of players for the game
    /// Randomly deal a hand to each player
    pub fn initPlayers(
        allocator: std.mem.Allocator,
        num_players: PlayerCount,
    ) !std.ArrayList(Player) {
        var players: std.ArrayList(Player) = try std.ArrayList(Player).initCapacity(
            allocator,
            @intFromEnum(num_players),
        );
        for (0..@intFromEnum(num_players)) |i| {
            try players.append(Player{
                .id = i,
                .team = (i % 2 == 0),
                .hand = undefined,
                .possibilities = undefined, // TODO: initialize possibilities to Unknown
            });
        }
        var hands: std.ArrayList(std.ArrayList(Card)) = try dealCards(
            allocator,
            num_players,
            null,
        );
        defer hands.deinit();
        for (0..@intFromEnum(num_players)) |i| {
            players.items[i].hand = hands.items[i];
        }
        return players;
    }

    test "initialize players" {
        const allocator = std.testing.allocator;
        var players: std.ArrayList(Player) = try Player.initPlayers(
            allocator,
            PlayerCount.SIX,
        );
        defer players.deinit();
        for (players.items) |player| {
            try expect(player.hand.items.len == 8);
        }
    }
};
