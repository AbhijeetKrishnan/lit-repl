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

    pub fn format(self: Rank, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
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
            Rank.Two, Rank.Three, Rank.Four, Rank.Five, Rank.Six, Rank.Seven, Rank.Nine, Rank.Ten, Rank.Jack, Rank.Jack, Rank.Queen, Rank.Queen, Rank.King, Rank.King, Rank.Ace, Rank.Ace,
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

    pub fn format(self: Card, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;

        try writer.print("{}{}", .{ self.suit, self.rank }); // TODO: investigate using the unicode versions of each card https://en.wikipedia.org/wiki/Playing_cards_in_Unicode#Playing_cards_deck
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

        return Card{ .suit = suit, .rank = rank };
    }

    test "parse a card" {
        var card: Card = try Card.parseCard("2C");
        std.debug.print("{any}\n", .{card});
        try expect(card.suit == Suit.Clubs);
        try expect(card.rank == Rank.Two);
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
    id: usize, // player ID, used as index into players array
    team: bool, // false = even, true = odd
    hand: std.ArrayList(Card),
    possibilities: [48]Possibility, // 48 cards grouped into 8 sets of 6

    pub fn format(self: Player, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;

        try writer.print("ID: {}\n", .{self.id});
        try writer.print("Team: {}\n", .{self.team});
        try writer.print("Hand: {s}", .{self.hand.items});
        // try writer.print("Possibilities: {any}\n", .{self.possibilities});
    }

    test "display players" {
        var players: std.ArrayList(Player) = try Player.initPlayers(PlayerCount.SIX);
        for (players.items) |player| {
            std.debug.print("{any}\n", .{player});
        }
    }

    /// Initialize the set of players for the game
    /// Randomly deal a hand to each player
    fn initPlayers(allocator: std.mem.Allocator, num_players: PlayerCount) !std.ArrayList(Player) {
        var players: std.ArrayList(Player) = try std.ArrayList(Player).initCapacity(allocator, @intFromEnum(num_players));
        for (0..@intFromEnum(num_players)) |i| {
            try players.append(Player{
                .id = i,
                .team = (i % 2 == 0),
                .hand = undefined,
                .possibilities = undefined, // TODO: initialize possibilities to Unknown
            });
        }
        var hands: std.ArrayList(std.ArrayList(Card)) = try dealCards(allocator, num_players, null);
        defer hands.deinit();
        for (0..@intFromEnum(num_players)) |i| {
            players.items[i].hand = hands.items[i];
        }
        return players;
    }
};

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
fn dealCards(allocator: std.mem.Allocator, num_players: PlayerCount, seed: ?u64) !std.ArrayList(std.ArrayList(Card)) { // TODO: pass seed as optional param
    var deck: [48]Card = comptime generateDeck();
    var true_seed: u64 = undefined;

    if (seed) |s| {
        true_seed = s;
    } else {
        try std.os.getrandom(std.mem.asBytes(&true_seed));
    }

    var prng = std.rand.DefaultPrng.init(true_seed);
    const rand = &prng.random();

    rand.shuffle(Card, &deck);

    var hands: std.ArrayList(std.ArrayList(Card)) = try std.ArrayList(std.ArrayList(Card)).initCapacity(allocator, @intFromEnum(num_players));
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
    var hands: std.ArrayList(std.ArrayList(Card)) = try dealCards(PlayerCount.SIX, 0);
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
    current_player: *Player, // current player

    pub fn format(self: Game, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
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

    test "display a game" {
        var game: Game = try Game.init(PlayerCount.SIX);
        std.debug.print("{}\n", .{game});
    }

    /// Initialize a new game
    pub fn init(allocator: std.mem.Allocator, num_players: PlayerCount) !Game {
        var game: Game = undefined;
        game.num_players = num_players;
        game.players = try Player.initPlayers(allocator, num_players);
        game.odd_sets = 0;
        game.even_sets = 0;
        game.current_player = &game.players.items[0]; // game starts with player 0
        return game;
    }

    pub fn deinit(self: *Game) !void {
        for (self.players.items) |player| {
            player.hand.deinit();
        }
        self.players.deinit();
    }

    /// Get player given player ID // TODO: get player by name/alias
    pub fn getPlayer(self: *const Game, player_id: u8) *Player {
        return &self.players.items[player_id]; // TODO: shouldn't this possibly fail if index is out of bounds?
    }

    /// Ask a player for a card
    /// Returns true if the card was found and performs the transfer between
    /// players
    /// Returns false if the card was not found and passes the turn to the asked
    /// player
    pub fn ask(self: *Game, asked_player: *Player, asked_card: Card) !bool {
        var asking_player = self.current_player;
        try expect(asking_player.team != asked_player.team); // TODO: display error
        try expect(asked_player.hand.items.len > 0); // TODO: display error
        // TODO: handle check for half-suit of card being asked being present in asking player's hand
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
        return found;
    }
};
