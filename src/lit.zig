const std = @import("std");

const Suit = enum(u8) {
    Clubs = 0,
    Diamonds = 1,
    Hearts = 2,
    Spades = 3,
};

const Rank = enum(u8) { Two = 0, Three = 1, Four = 2, Five = 3, Six = 4, Seven = 5, Nine = 6, Ten = 7, Jack = 8, Queen = 9, King = 10, Ace = 11 };

const Card = struct { suit: Suit, rank: Rank };

const Possibility = enum(u8) {
    Unknown = 0,
    No = 1,
    Possible = 2,
    Yes = 3,
};

const Player = struct {
    team: bool, // false = even, true = odd
    hand: std.ArrayList(Card),
    possibilities: [48]Possibility, // 48 cards grouped into 8 sets of 6
};

pub fn init_players(num_players: u8) []Player {
    var players: [num_players]Player = undefined;
    for (0..num_players) |i| {
        players[i].team = (i % 2 == 0);
        players[i].hand = undefined; // TODO: shuffle deck and assign randomly
        players[i].possibilities = undefined; // TODO: initialize possibilities to Unknown
    }
    return players;
}

pub const Game = struct {
    players: []Player,
    num_players: u8, // 6
    odd_sets: u8, // odd team sets
    even_sets: u8, // even team sets
};

pub fn init_game(num_players: u8) Game {
    var game: Game = undefined;
    game.num_players = num_players;
    game.players = init_players(num_players);
    game.odd_sets = 0;
    game.even_sets = 0;
    return game;
}
