# ExDiceRoller

[![Build Status](https://travis-ci.org/rishenko/ex_dice_roller.svg?branch=master)](https://travis-ci.org/rishenko/ex_dice_roller)
[![Coverage Status](https://coveralls.io/repos/github/rishenko/ex_dice_roller/badge.svg?branch=master)](https://coveralls.io/github/rishenko/ex_dice_roller?branch=master)
[![Hex.pm Version](https://img.shields.io/hexpm/v/ex_dice_roller.svg?style=flat)](https://hex.pm/packages/ex_dice_roller)

Provides functionality around calculating both simple and complex dice rolling equations.

## Features

* Supports common math operators: `+`, `-`, `*`, `/`
* Supports `+` and `-` unary operators.
* Supports creating common expressions and parenthetically grouped expressions into complex dice-roll equations.
* Supports creating uncommon dice rolls, such as `(1d4)d(3d6)-(1d4+7)`.
* Supports using variables in expressions that can be given values upon use, such as `1dx+y`.
* Allows developers to tokenize, parse, and then compile dice roll strings into reusable anonymous functions.


## Installation

Add `:ex_dice_roller` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ex_dice_roller, "~> 0.2.0-alpha"}
  ]
end
```

Next, run:
```
$ mix deps.get
```


## Usage

ExDiceRoller supports a variety of possible dice roll permutations that can be used in your application.

```elixir
  iex> ExDiceRoller.roll("1")
  1

  iex> ExDiceRoller.roll("1+2")
  3

  iex> ExDiceRoller.roll("1d6")
  1

  iex> ExDiceRoller.roll("1d20-5")
  12

  iex> ExDiceRoller.roll("1d20-(5*6)")
  -28

  iex> ExDiceRoller.roll("1d4d6")
  10

  iex> ExDiceRoller.roll("(1d4+2)d8")
  28

  iex> ExDiceRoller.roll("(1d4+2)d(1d20)")
  16

  iex> ExDiceRoller.roll("(1d4+2)d((5*6)d20-5)")
  677

  iex> ExDiceRoller.roll("1dx+y", x: 20, y: 13)
  16
```


## Compiled Expressions

Parsed expressions can be compiled into a single, executable anonymous
function. This function can be reused again and again, with any dice rolls
being randomized and calculated for each call.

Note that while `ExDiceRoller.roll/1` always returns integers, `ExDiceRoller.execute/1` will
return either floats or integers.

```elixir
  iex> {:ok, roll_fun} = ExDiceRoller.compile("1d6 - (3d6)d5 + (1d4)/5")
  {:ok, #Function<6.11371143/0 in ExDiceRoller.Compiler.compile_op/5>}

  iex> ExDiceRoller.execute(roll_fun)
  21.6

  iex> ExDiceRoller.execute(roll_fun)
  34.4

  iex> {:ok, roll_fun} = ExDiceRoller.compile("1dx+10")
  {:ok, #Function<8.36233920/1 in ExDiceRoller.Compiler.compile_op/5>}

  iex> ExDiceRoller.execute(roll_fun, x: 5)
  11

  iex> ExDiceRoller.execute(roll_fun, x: "10d100")
  523
```


## How It Works

1. ExDiceRoller utilizes Erlang's [leex](http://erlang.org/doc/man/leex.html) library to tokenize a given dice roll string.
2. The tokens are then passed to [yecc](http://erlang.org/doc/man/yecc.html) which parses the tokens into an abstract 
syntax tree.
3. The syntax tree is then interpreted through recursive navigation.
4. During interpretation:
  1. Any basic numerical values are calculated.
  2. Any dice rolls are converted into anonymous functions.
  3. Any portion of the expression or equation that use both base values and
  dice rolls are converted into anonymous functions.
1. The results of interpretation are then wrapped by a final anonymous
function.
6. This final anonymous function is then executed and the value returned.

```elixir
  iex(3)> expr = "(1d4+2)d((5*6)d20-5)"
  "(1d4+2)d((5*6)d20-5)"

  iex(4)> {:ok, tokens} = ExDiceRoller.tokenize(expr)
  {:ok,
  [
    {:"(", 1, '('},
    {:digit, 1, '1'},
    {:roll, 1, 'd'},
    {:digit, 1, '4'},
    {:basic_operator, 1, '+'},
    {:digit, 1, '2'},
    {:")", 1, ')'},
    {:roll, 1, 'd'},
    {:"(", 1, '('},
    {:"(", 1, '('},
    {:digit, 1, '5'},
    {:complex_operator, 1, '*'},
    {:digit, 1, '6'},
    {:")", 1, ')'},
    {:roll, 1, 'd'},
    {:digit, 1, '20'},
    {:basic_operator, 1, '-'},
    {:digit, 1, '5'},
    {:")", 1, ')'}
  ]}

  iex(5)> {:ok, ast} = ExDiceRoller.parse(tokens)
  {:ok,
  {:roll,
    {{:operator, '+'},
      {:roll, {:digit, '1'}, {:digit, '4'}},
      {:digit, '2'}},
    {{:operator, '-'},
      {:roll, 
        {{:operator, '*'}, {:digit, '5'}, {:digit, '6'}},
        {:digit, '20'}},
      {:digit, '5'}}}}

  iex(6)> {:ok, roll_fun} = ExDiceRoller.compile(ast)
  {:ok, #Function<12.11371143/0 in ExDiceRoller.Compiler.compile_roll/4>}

  iex(7)> roll_fun.()
  739

  iex(8)> roll_fun.()
  905
```


## Test Coverage and More

* [ex_coveralls](https://github.com/parroty/excoveralls) provides test coverage metrics.
* [credo](https://github.com/rrrene/credo) is used for static code analysis.
