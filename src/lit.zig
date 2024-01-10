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

        try writer.print("{}{}", self.suit, self.suit); // TODO: investigate using the unicode versions of each card https://en.wikipedia.org/wiki/Playing_cards_in_Unicode#Playing_cards_deck
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
};

const Player = struct {
    team: bool, // false = even, true = odd
    hand: std.ArrayList(Card),
    possibilities: [48]Possibility, // 48 cards grouped into 8 sets of 6
};

fn generateDeck() [48]Card {
    var deck: [48]Card = undefined;
    var ptr: u8 = 0;
    for (Suit.Clubs..Suit.Spades) |suit| {
        for (Rank.Two..Rank.Ace) |rank| {
            deck[ptr] = Card{ .suit = suit, .rank = rank };
            ptr += 1;
        }
    }
    return deck;
}

test "generate a deck" {
    var deck: [48]Card = generateDeck();
    std.debug.print("{}\n", deck);
    try expect(deck.len == 48);
}

/// Deal cards to each player
fn dealCards(num_players: PlayerCount) []std.ArrayList(Card) {
    var deck: [48]Card = comptime generateDeck();
    deck.shuffle();

    var hands: [num_players]std.ArrayList(Card) = undefined;
    const hand_size: u8 = 48 / num_players;
    for (0..num_players) |i| {
        hands[i] = std.ArrayList(Card).init(hand_size);
        for (0..hand_size) |j| {
            _ = j;
            hands[i].append(deck.pop());
        }
    }
    return hands;
}

test "deal cards" {
    var hands: []std.ArrayList(Card) = dealCards(PlayerCount.SIX);
    std.debug.print("{}\n", hands);
    try expect(hands.len == 6);
    for (hands) |hand| {
        try expect(hand.len == 8);
    }
}

/// Initialize the set of players for the game
/// Randomly deal a hand to each player
fn initPlayers(num_players: PlayerCount) error{OutOfMemory}!std.ArrayList(Player) {
    var heap_allocator = std.heap.page_allocator;
    var players: std.ArrayList(Player) = std.ArrayList(Player).init(heap_allocator);
    for (0..@intFromEnum(num_players)) |i| {
        try players.append(Player{
            .team = (i % 2 == 0),
            .hand = undefined, // TODO: shuffle deck and assign randomly
            .possibilities = undefined, // TODO: initialize possibilities to Unknown
        });
    }
    return players;
}

pub const Game = struct {
    players: std.ArrayList(Player),
    num_players: PlayerCount = PlayerCount.SIX, // 6
    odd_sets: u8 = 0, // count of odd team sets
    even_sets: u8 = 0, // count of even team sets

    /// Initialize a new game
    pub fn init(num_players: PlayerCount) error{OutOfMemory}!Game {
        var game: Game = undefined;
        game.num_players = num_players;
        game.players = try initPlayers(num_players);
        game.odd_sets = 0;
        game.even_sets = 0;
        return game;
    }
};
