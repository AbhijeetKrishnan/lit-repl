# REPL for Infinite!Lit

A Zig-based command-line tool to play the card game [Lit](https://www.pagat.com/quartet/literature.html) (also called Literature or Canadian Fish) while viewing the board state and possibility space at each turn.

![Zig](https://img.shields.io/badge/Zig-%23F7A41D.svg?style=for-the-badge&logo=zig&logoColor=white)

## Installation

_Written using Zig v.0.11.0_

```bash
$ git clone git@github.com:AbhijeetKrishnan/lit-repl
$ cd lit-repl
$ zig build
```

## Motivation

I found playing Lit fun, and wanted to devise an optimal strategy. However, it requires modeling human memory accurately, which is probably out of scope. Assuming an agent has access to infinite memory to remember all questions asked so far, and model the other players' hands as richly as they want, what would the optimal strategy look like _then_? This variant is what I have dubbed "Infinite!Lit".

## Usage

```bash
$ ./zig-out/bin/lit-repl
```