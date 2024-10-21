const std = @import("std");
const expect = std.testing.expect;

pub const Suit = enum(u8) {
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
        const card: Card = try Card.parseCard("2C");
        std.debug.print("{any}\n", .{card});
        try expect(card.suit == Suit.Clubs);
        try expect(card.rank == Rank.Two);
    }

    /// Get the half of a card (low or high)
    pub fn get_half_suit(self: Card) Half {
        return if (@intFromEnum(self.rank) <= @intFromEnum(Rank.Seven)) Half.Low else Half.High;
    }

    /// Check if card is in a particular half-suit
    fn in_half_suit(self: Card, half: Half, suit: Suit) bool {
        return self.get_half_suit() == half and self.suit == suit;
    }
};

/// Converts a string of comma-separated cards into Card objects
///
/// - Parameters:
///   - allocator: an allocator to use for memory allocation
///   - cards_str: a string of comma-separated cards
/// - Returns:
///   - an `ArrayList` of `Card` objects if parsing is successful, otherwise a `GameError.MalformedClaim` error
fn parse_cards_list(allocator: std.mem.Allocator, cards_str: []const u8) !std.ArrayList(Card) {
    var cards: std.ArrayList(Card) = std.ArrayList(Card).init(allocator);
    var splits = std.mem.splitSequence(u8, cards_str, ",");
    while (splits.next()) |card_str| {
        const trimmed_card_str = std.mem.trim(u8, card_str, " ");
        const card = try Card.parseCard(trimmed_card_str);
        try cards.append(card);
    }
    return cards;
}

test "parse a list of cards" {
    const allocator = std.testing.allocator;
    const cards_str = "2C, 3D, 4H, 5S";
    const cards: std.ArrayList(Card) = try parse_cards_list(allocator, cards_str);
    defer cards.deinit();
    std.debug.print("{any}\n", .{cards});
    try expect(cards.items.len == 4);
}

pub const Half = enum(u8) {
    Low,
    High,
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

    pub fn deinit(self: *const Player) !void {
        self.hand.deinit();
    }

    pub fn format(self: Player, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;

        try writer.print("ID: {}\n", .{self.id});
        try writer.print("Team: {}\n", .{self.team});
        try writer.print("Hand: {s}", .{self.hand.items});
        // try writer.print("Possibilities: {any}\n", .{self.possibilities});
    }

    test "display players" {
        const allocator = std.testing.allocator;
        var players: std.ArrayList(Player) = try Player.initPlayers(allocator, PlayerCount.SIX);
        defer players.deinit();
        for (players.items) |player| {
            std.debug.print("{any}\n", .{player});
            defer player.deinit() catch |err| {
                std.debug.print("Error: {any}\n", .{err});
            };
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

/// Generate a deck of 48 cards (with eights removed)
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
    const deck: [48]Card = generateDeck();
    std.debug.print("{any}\n", .{deck});
    try expect(deck.len == 48);
}

/// Deal cards to each player randomly
fn dealCards(allocator: std.mem.Allocator, num_players: PlayerCount, seed: ?u64) !std.ArrayList(std.ArrayList(Card)) {
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
    const allocator = std.testing.allocator;
    var hands: std.ArrayList(std.ArrayList(Card)) = try dealCards(allocator, PlayerCount.SIX, 0);

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

/// Check if deck contains a card from the same half-suit as another card
fn halfSuitExists(hand: []const Card, card: Card) bool {
    const half = card.get_half_suit();
    const suit = card.suit;
    for (hand) |c| {
        if (c.in_half_suit(half, suit)) {
            return true;
        }
    }
    return false;
}

/// A record of a game actions
pub const HistoryRecord = struct {
    asker: *Player,
    askee: *Player,
    card: Card,
    success: bool,

    pub fn format(self: HistoryRecord, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;

        try writer.print("Player {d} {s} asked Player {d} for card {any}", .{ self.asker.id, if (self.success) "successfully" else "unsucessfully", self.askee.id, self.card });
    }

    pub fn init(asker: *Player, askee: *Player, card: Card, success: bool) HistoryRecord {
        return HistoryRecord{ .asker = asker, .askee = askee, .card = card, .success = success };
    }
};

pub const GameError = error{ PlayerIndexOutOfBounds, AskingSelfTeam, AskingFromEmpty, HalfSuitAbsent, PartialHalfSetClaimed, MalformedClaim, CurrentPlayerMustClaim };

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

    /// Initialize a new game
    pub fn init(allocator: std.mem.Allocator, num_players: PlayerCount) !Game {
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
        const allocator = std.testing.allocator;
        var game: Game = try Game.init(allocator, PlayerCount.SIX);
        std.debug.print("{}\n", .{game});
        defer game.deinit() catch |err| {
            std.debug.print("Error: {any}\n", .{err});
        };
    }

    /// Get player given player ID // TODO: get player by name/alias
    pub fn getPlayer(self: *const Game, player_id: u8) !*Player {
        if (player_id >= self.players.items.len or player_id < 0) {
            return GameError.PlayerIndexOutOfBounds;
        }
        return &self.players.items[player_id];
    }

    /// Ask a player for a card
    /// - Returns:
    ///     true if the card was found and performs the transfer between players
    ///     false if the card was not found and passes the turn to the asked player
    pub fn ask(self: *Game, asked_player: *Player, asked_card: Card) !bool {
        var asking_player = self.current_player;
        if (!(asking_player.team != asked_player.team))
            return GameError.AskingSelfTeam;
        if (asked_player.hand.items.len <= 0)
            return GameError.AskingFromEmpty;
        if (!halfSuitExists(asking_player.hand.items, asked_card))
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
        try self.history.append(HistoryRecord.init(asking_player, asked_player, asked_card, found));
        return found;
    }

    /// Helper function to build a list of claims given a list of string-based claims from a player
    pub fn build_claims_list(self: *const Game, allocator: std.mem.Allocator, claiming_player: *const Player, claims_strs: []const []const u8) !std.ArrayList(std.ArrayList(Card)) {
        var claims_list: std.ArrayList(std.ArrayList(Card)) = try std.ArrayList(std.ArrayList(Card)).initCapacity(allocator, @intFromEnum(self.num_players) / 2);
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
                // '=' not present, player ID is that of claiming player, and entire string is list of comma-separated cards
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
        const game = Game{ .players = undefined, .num_players = PlayerCount.SIX, .odd_sets = 0, .even_sets = 0, .current_player = undefined, .history = undefined };
        const player = Player{ .id = 0, .team = false, .hand = undefined, .possibilities = undefined };
        const claims_strs = [_][]const u8{
            "4=2C, 3D, 4H,5S ",
            "2C, 3D,4H, 5S",
            "2=3D,4H, 5S",
        };
        const claims_list: std.ArrayList(std.ArrayList(Card)) = try game.build_claims_list(allocator, &player, &claims_strs);
        defer claims_list.deinit();
        for (claims_list.items) |claim| {
            std.debug.print("{any}\n", .{claim});
            defer claim.deinit();
        }
    }

    /// Check whether the claim for a suit is valid
    pub fn check_claim(self: *const Game, claiming_player: *const Player, half: Half, suit: Suit, claims: std.ArrayList(std.ArrayList(Card))) !ClaimOutcome {
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

    /// Given a claim, execute it
    pub fn execute_claim(self: *Game, claiming_player: *Player, half: Half, suit: Suit, outcome: ClaimOutcome) !void {
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
};
