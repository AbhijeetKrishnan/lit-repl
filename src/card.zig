const std = @import("std");
const expect = std.testing.expect;

pub const Suit = enum(u8) {
    Clubs,
    Diamonds,
    Hearts,
    Spades,

    pub fn format(
        self: Suit,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;

        switch (self) {
            .Clubs => try writer.writeAll("♣"),
            .Diamonds => try writer.writeAll("♦"),
            .Hearts => try writer.writeAll("♥"),
            .Spades => try writer.writeAll("♠"),
        }
    }

    pub fn parseSuit(suit: []const u8) !Suit {
        return switch (suit[0]) {
            'c', 'C' => Suit.Clubs,
            'd', 'D' => Suit.Diamonds,
            'h', 'H' => Suit.Hearts,
            's', 'S' => Suit.Spades,
            else => undefined,
        };
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

    pub fn format(
        self: Rank,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;

        switch (self) {
            .Two => try writer.writeAll("2"),
            .Three => try writer.writeAll("3"),
            .Four => try writer.writeAll("4"),
            .Five => try writer.writeAll("5"),
            .Six => try writer.writeAll("6"),
            .Seven => try writer.writeAll("7"),
            .Nine => try writer.writeAll("9"),
            .Ten => try writer.writeAll("10"),
            .Jack => try writer.writeAll("J"),
            .Queen => try writer.writeAll("Q"),
            .King => try writer.writeAll("K"),
            .Ace => try writer.writeAll("A"),
        }
    }

    test "format rank" {
        std.debug.print("TODO: implement\n", .{});
        unreachable;
    }

    pub fn parseRank(rank: []const u8) !Rank {
        return switch (rank[0]) {
            '2' => Rank.Two,
            '3' => Rank.Three,
            '4' => Rank.Four,
            '5' => Rank.Five,
            '6' => Rank.Six,
            '7' => Rank.Seven,
            '9' => Rank.Nine,
            '0' => Rank.Ten,
            '1' => {
                return switch (rank[1]) {
                    '0' => Rank.Ten,
                    else => undefined,
                };
            },
            'j', 'J' => Rank.Jack,
            'q', 'Q' => Rank.Queen,
            'k', 'K' => Rank.King,
            'a', 'A' => Rank.Ace,
            else => undefined,
        };
    }

    test "parse rank" {
        var rank: Rank = undefined;
        const tests = [_]u8{
            '2', '3', '4', '5', '6', '7', '9', '0', 'j', 'J', 'q', 'Q', 'k', 'K', 'a', 'A',
        };
        const expected = [_]Rank{
            Rank.Two,  Rank.Three, Rank.Four,  Rank.Five, Rank.Six,  Rank.Seven, Rank.Nine, Rank.Ten, Rank.Jack,
            Rank.Jack, Rank.Queen, Rank.Queen, Rank.King, Rank.King, Rank.Ace,   Rank.Ace,
        };
        for (tests, expected) |t, e| {
            rank = try Rank.parseRank(&[_]u8{t});
            std.debug.print("{c}\n", .{t});
            try expect(rank == e);
        }
        try expect(try Rank.parseRank("10") == Rank.Ten);
    }
};

pub const Card = struct {
    suit: Suit,
    rank: Rank,

    pub fn format(
        self: Card,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;

        try writer.print("{}{}", .{
            self.suit,
            self.rank,
        }); // TODO: investigate using the unicode versions of each card https://en.wikipedia.org/wiki/Playing_cards_in_Unicode#Playing_cards_deck
    }

    test "format a card" {
        std.debug.print("TODO: implement\n", .{});
        unreachable;
    }

    pub fn parseCard(card: []const u8) !Card {
        var rank: Rank = undefined;
        var suit: Suit = undefined;
        switch (card.len) {
            2 => {
                rank = try Rank.parseRank(card[0..1]);
                suit = try Suit.parseSuit(card[1..2]);
            },
            3 => {
                rank = try Rank.parseRank(card[0..2]);
                suit = try Suit.parseSuit(card[2..3]);
            },
            else => return undefined,
        }

        return Card{
            .suit = suit,
            .rank = rank,
        };
    }

    test "parse a card" {
        const card: Card = try Card.parseCard("2C");
        std.debug.print("{any}\n", .{card});
        try expect(card.suit == Suit.Clubs);
        try expect(card.rank == Rank.Two);
    }

    /// Get the half of a card (low or high)
    pub fn get_half_suit(self: Card) Half {
        return if (@intFromEnum(self.rank) <= @intFromEnum(Rank.Seven)) Half.Low else Half.High;
    }

    test "get half suit" {
        const card: Card = Card{
            .suit = Suit.Clubs,
            .rank = Rank.Seven,
        };
        try expect(card.get_half_suit() == Half.Low);
    }

    /// Check if card is in a particular half-suit
    pub fn in_half_suit(
        self: Card,
        half: Half,
        suit: Suit,
    ) bool {
        return self.get_half_suit() == half and self.suit == suit;
    }

    test "check if card is in half suit" {
        const card: Card = Card{
            .suit = Suit.Clubs,
            .rank = Rank.Seven,
        };
        try expect(card.in_half_suit(Half.Low, Suit.Clubs));
        try expect(!card.in_half_suit(Half.High, Suit.Clubs));
        try expect(!card.in_half_suit(Half.Low, Suit.Diamonds));
    }
};

/// Converts a string of comma-separated cards into Card objects
///
/// - Parameters:
///   - allocator: an allocator to use for memory allocation
///   - cards_str: a string of comma-separated cards
/// - Returns:
///   - an `ArrayList` of `Card` objects if parsing is successful, otherwise a `GameError.MalformedClaim` error
pub fn parse_cards_list(
    allocator: std.mem.Allocator,
    cards_str: []const u8,
) !std.ArrayList(Card) {
    var cards: std.ArrayList(Card) = std.ArrayList(Card).init(allocator);
    var splits = std.mem.splitSequence(
        u8,
        cards_str,
        ",",
    );
    while (splits.next()) |card_str| {
        const trimmed_card_str = std.mem.trim(
            u8,
            card_str,
            " ",
        );
        const card = try Card.parseCard(trimmed_card_str);
        try cards.append(card);
    }
    return cards;
}

test "parse a list of cards" {
    const allocator = std.testing.allocator;
    const cards_str = "2C, 3D, 4H, 5S";
    const cards: std.ArrayList(Card) = try parse_cards_list(
        allocator,
        cards_str,
    );
    defer cards.deinit();
    std.debug.print("{any}\n", .{cards});
    try expect(cards.items.len == 4);
}

pub const Half = enum(u8) {
    Low,
    High,
};

pub const Possibility = enum(u8) {
    Unknown,
    No,
    Possible,
    Yes,
};

/// Generate a deck of 48 cards (with eights removed)
pub fn generateDeck() [48]Card {
    var deck: [48]Card = undefined;
    var ptr: u8 = 0;
    for (std.enums.values(Suit)) |suit| {
        for (std.enums.values(Rank)) |rank| {
            deck[ptr] = Card{
                .suit = suit,
                .rank = rank,
            };
            ptr += 1;
        }
    }
    return deck;
}

test "generate a deck" {
    const deck: [48]Card = generateDeck();
    std.debug.print("{any}\n", .{deck});
    try expect(deck.len == 48);
}

/// Check if deck contains a card from the same half-suit as another card
pub fn halfSuitExists(
    hand: []const Card,
    card: Card,
) bool {
    const half = card.get_half_suit();
    const suit = card.suit;
    for (hand) |c| {
        if (c.in_half_suit(half, suit)) {
            return true;
        }
    }
    return false;
}

test "check if half suit exists" {
    const hand: [8]Card = [_]Card{
        Card{ .suit = Suit.Clubs, .rank = Rank.Two },
        Card{ .suit = Suit.Clubs, .rank = Rank.Three },
        Card{ .suit = Suit.Clubs, .rank = Rank.Four },
        Card{ .suit = Suit.Clubs, .rank = Rank.Five },
        Card{ .suit = Suit.Clubs, .rank = Rank.Six },
        Card{ .suit = Suit.Clubs, .rank = Rank.Seven },
        Card{ .suit = Suit.Clubs, .rank = Rank.Nine },
        Card{ .suit = Suit.Clubs, .rank = Rank.Ten },
    };
    const card: Card = Card{
        .suit = Suit.Clubs,
        .rank = Rank.Seven,
    };
    try expect(halfSuitExists(&hand, card));
}
