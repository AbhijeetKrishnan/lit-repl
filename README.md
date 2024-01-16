# REPL for Infinite!Lit

A Zig-based command-line tool to play the card game [Lit](https://www.pagat.com/quartet/literature.html) (also called Literature or Canadian Fish) while viewing the board state and possibility space at each turn.

![Zig](https://img.shields.io/badge/Zig-%23F7A41D.svg?style=for-the-badge&logo=zig&logoColor=white)

## Motivation

I found playing Lit fun, and wanted to devise an optimal strategy. However, it requires modeling human memory accurately, which is probably out of scope. Assuming an agent has access to infinite memory to remember all questions asked so far, and model the other players' hands as richly as they want, what would the optimal strategy look like _then_? This variant is what I have dubbed "Infinite!Lit".

## Installation

_Written using Zig v.0.11.0_

```bash
$ git clone git@github.com:AbhijeetKrishnan/lit-repl
$ cd lit-repl
$ zig build
```

Run all tests using -

```bash
zig test src/main.zig
```

## Usage

Infinite!Lit is implemented as an interpreter which allows you to run commands to start a new game of Lit, ask for cards, and claim hands. You can also view the game state at any time, including the list of possibilities for cards that other players might have.

Start the program with -

```bash
$ zig build run
Welcome to the Infinite!Lit REPL v0.0.1.
Type "help" for more information, "init" to start a new game, or "exit" to close the program.
```

To initialize a new game -
```bash
lit> init
Initialized a new game with 6 players.
lit 0*>
```

The `0*` indicates that it is Player 0's turn to play.

To view the current game state -
```bash
lit> show
ID: 0
Team: true
Hand: { ♣J, ♠2, ♥3, ♦4, ♠9, ♠Q, ♣6, ♣Q }
ID: 1
Team: false
Hand: { ♦2, ♠6, ♥10, ♣4, ♦10, ♠J, ♥4, ♣K }
ID: 2
Team: true
Hand: { ♦9, ♠A, ♥9, ♠K, ♦3, ♦6, ♣2, ♣9 }
ID: 3
Team: false
Hand: { ♦7, ♠4, ♣7, ♣A, ♥7, ♦A, ♣10, ♠5 }
ID: 4
Team: true
Hand: { ♣5, ♥6, ♥2, ♦J, ♦K, ♥A, ♥5, ♦Q }
ID: 5
Team: false
Hand: { ♥Q, ♦5, ♥K, ♣3, ♠7, ♥J, ♠10, ♠3 }
Num Players: 6
Odd Sets: 0
Even Sets: 0
Current Player: ID: 0
Team: true
Hand: { ♣J, ♠2, ♥3, ♦4, ♠9, ♠Q, ♣6, ♣Q }

```

To get a list of all commands -
```bash
lit> help
  help: print this help text
  exit: exit the Infinite!Lit REPL
  init: start a new game with 6 players
  ask [player] [card]: ask a player for a card
  last [n]: show the last n asks
  show: show the current game state
  claim <cardlist> [player]=<cardlist>: claim a set
  end: terminate the game
```

To exit the program -
```bash
lit> exit
Exiting...
$ 
```

To ask for a card -
```bash
lit 0*> ask 1 2d
Yes. Player 0 receives card ♦2 from Player 1.
lit 0*> ask 1 3d
No. Turn passes to Player 1
lit 1*> 
```

Cards are represented using a string that is matched by the regex `(?<val>[02-9jqka])(?<suit>[cdhs])`

| Suit | Symbol |
| :--: | :----: |
| Clubs (♣) | `c` |
| Diamonds (♦) | `d` |
| Hearts (♥) | `h` |
| Spades (♠) | `s` |

| Rank | Symbol |
| :--: | :----: |
| 2 | `2` |
| 3 | `3` |
| 4 | `4` |
| 5 | `5` |
| 6 | `6` |
| 7 | `7` |
| 8 | `8` |
| 9 | `9` |
| 10 | `0`, `10` |
| Jack | `j` |
| Queen | `q` |
| King | `k` |
| Ace | `a` |

To view the last $n$ asks -
```bash
lit 0*> last 2
2. Player 0 asked Player 1 for card ♦3
1. Player 1 asked Player 0 for card ♦2
lit 0*> 
```

To claim a set - (TODO:)
```bash
lit 0*> claim 2c,3c 2=4c,7c,6c 4=5c
```

To terminate a game -
```bash
lit 0*> end
Game terminated.
lit> 
```