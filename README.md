# DiceRoller

Provides functionality around dice rolling.

## Features

* Supports common math operators: `+`, `-`, `*`, `/`
* Supports combining common expressions and parenthetically grouped expressions.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `dice_roller` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:dice_roller, "~> 0.1.0"}
  ]
end
```

## Example Usage

DiceRoller supports a variety of possible dice rolls that can be used in your
application.

```
  iex> DiceRoller.roll("1")
  1

  iex> DiceRoller.roll("1+2")
  3

  iex> DiceRoller.roll("1d6")
  1

  iex> DiceRoller.roll("1d100")
  92

  iex> DiceRoller.roll("1d20-5")
  12

  iex> DiceRoller.roll("1d20-(5*6)")
  -28

  iex> DiceRoller.roll("1d4d6")
  10

  iex> DiceRoller.roll("(1d4+2)d8")
  28

  iex> DiceRoller.roll("(1d4+2)d(1d20)")
  16

  iex> DiceRoller.roll("(1d4+2)d((5*6)d20-5)")
  677
```

## How It Works

DiceRoller uses output from leex and yecc to tokenize and parse dice roll
strings into an abstract syntax tree. Functions then recursively navigate
the and calculate against the syntax tree to produce an integer result.

```
  iex> expr = "(1d4+2)d((5*6)d20-5)"
  "(1d4+2)d((5*6)d20-5)"

  iex> {:ok, tokens} = DiceRoller.tokenize(expr)
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

  iex> {:ok, ast} = DiceRoller.parse(tokens)
  {:ok,
  {:roll,
    {{:operator, '+'}, {:roll, {:digit, '1'}, {:digit, '4'}}, {:digit, '2'}},
    {{:operator, '-'},
    {:roll, {{:operator, '*'}, {:digit, '5'}, {:digit, '6'}}, {:digit, '20'}},
    {:digit, '5'}}}}
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/dice_roller](https://hexdocs.pm/dice_roller).

