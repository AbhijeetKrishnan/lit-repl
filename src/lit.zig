const std = @import("std");
const expect = std.testing.expect;

const Suit = enum(u8) {
    Clubs,
    Diamonds,
    Hearts,
    Spades,

    pub fn format(self: Suit, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;

        switch (self) {
            .Clubs => {
                try writer.writeAll("♣");
            },
            .Diamonds => {
                try writer.writeAll("♦");
            },
            .Hearts => {
                try writer.writeAll("♥");
            },
            .Spades => {
                try writer.writeAll("♠");
            },
        }
    }
};

const Rank = enum(u8) {
    Two,
    Three,
    Four,
    Five,
    Six,
    Seven,
    // Eight, eights are removed from the deck
    Nine,
    Ten,
    Jack,
    Queen,
    King,
    Ace,

    pub fn format(self: Rank, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;

        switch (self) {
            .Two => {
                try writer.writeAll("2");
            },
            .Three => {
                try writer.writeAll("3");
            },
            .Four => {
                try writer.writeAll("4");
            },
            .Five => {
                try writer.writeAll("5");
            },
            .Six => {
                try writer.writeAll("6");
            },
            .Seven => {
                try writer.writeAll("7");
            },
            .Nine => {
                try writer.writeAll("9");
            },
            .Ten => {
                try writer.writeAll("10");
            },
            .Jack => {
                try writer.writeAll("J");
            },
            .Queen => {
                try writer.writeAll("Q");
            },
            .King => {
                try writer.writeAll("K");
            },
            .Ace => {
                try writer.writeAll("A");
            },
        }
    }
};

const Card = struct {
    suit: Suit,
    rank: Rank,

    pub fn format(self: Card, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;

        try writer.print("{}{}", .{ self.suit, self.rank }); // TODO: investigate using the unicode versions of each card https://en.wikipedia.org/wiki/Playing_cards_in_Unicode#Playing_cards_deck
    }
};

const Possibility = enum(u8) {
    Unknown,
    No,
    Possible,
    Yes,
};

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

const Player = struct {
    team: bool, // false = even, true = odd
    hand: std.ArrayList(Card),
    possibilities: [48]Possibility, // 48 cards grouped into 8 sets of 6

    pub fn format(self: Player, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;

        try writer.print("Team: {}\n", .{self.team});
        try writer.print("Hand: {any}\n", .{self.hand.items});
        try writer.print("Possibilities: {any}\n", .{self.possibilities});
    }

    /// Initialize the set of players for the game
    /// Randomly deal a hand to each player
    fn initPlayers(num_players: PlayerCount) !std.ArrayList(Player) {
        var heap_allocator = std.heap.page_allocator;
        var players: std.ArrayList(Player) = std.ArrayList(Player).init(heap_allocator);
        for (0..@intFromEnum(num_players)) |i| {
            try players.append(Player{
                .team = (i % 2 == 0),
                .hand = undefined,
                .possibilities = undefined, // TODO: initialize possibilities to Unknown
            });
        }
        var hands: std.ArrayList(std.ArrayList(Card)) = try dealCards(num_players);
        for (0..@intFromEnum(num_players)) |i| {
            players.items[i].hand = hands.items[i];
        }
        return players;
    }
};

test "display players" {
    var players: std.ArrayList(Player) = try Player.initPlayers(PlayerCount.SIX);
    for (players.items) |player| {
        std.debug.print("{any}\n", .{player});
    }
}

fn generateDeck() [48]Card {
    var deck: [48]Card = undefined;
    var ptr: u8 = 0;
    for (std.enums.values(Suit)) |suit| {
        for (std.enums.values(Rank)) |rank| {
            deck[ptr] = Card{ .suit = suit, .rank = rank };
            ptr += 1;
        }
    }
    return deck;
}

test "generate a deck" {
    var deck: [48]Card = generateDeck();
    std.debug.print("{any}\n", .{deck});
    try expect(deck.len == 48);
}

/// Deal cards to each player
fn dealCards(num_players: PlayerCount) !std.ArrayList(std.ArrayList(Card)) {
    var deck: [48]Card = comptime generateDeck();

    var seed: u64 = undefined;
    try std.os.getrandom(std.mem.asBytes(&seed));

    var prng = std.rand.DefaultPrng.init(seed);
    const rand = &prng.random();

    rand.shuffle(Card, &deck);

    var heap_allocator = std.heap.page_allocator;

    var hands: std.ArrayList(std.ArrayList(Card)) = std.ArrayList(std.ArrayList(Card)).init(heap_allocator);
    const hand_size: u8 = 48 / @intFromEnum(num_players);
    for (0..@intFromEnum(num_players)) |i| {
        var hand = std.ArrayList(Card).init(heap_allocator);
        for (0..hand_size) |j| {
            try hand.append(deck[i * hand_size + j]);
        }
        try hands.append(hand);
    }
    return hands;
}

test "deal cards" {
    var hands: std.ArrayList(std.ArrayList(Card)) = try dealCards(PlayerCount.SIX);
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
}

pub const Game = struct {
    players: std.ArrayList(Player),
    num_players: PlayerCount = PlayerCount.SIX,
    odd_sets: u8 = 0, // count of odd team sets
    even_sets: u8 = 0, // count of even team sets

    pub fn format(self: Game, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;

        for (self.players.items) |player| {
            try writer.print("{any}\n", .{player});
        }
        try writer.print("Num Players: {d}\n", .{@intFromEnum(self.num_players)});
        try writer.print("Odd Sets: {d}\n", .{self.odd_sets});
        try writer.print("Even Sets: {d}\n", .{self.even_sets});
    }

    /// Initialize a new game
    pub fn init(num_players: PlayerCount) !Game {
        var game: Game = undefined;
        game.num_players = num_players;
        game.players = try Player.initPlayers(num_players);
        game.odd_sets = 0;
        game.even_sets = 0;
        return game;
    }
};

test "display a game" {
    var game: Game = try Game.init(PlayerCount.SIX);
    std.debug.print("{}\n", .{game});
}
