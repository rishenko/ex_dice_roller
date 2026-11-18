# ExDiceRoller

[![CI](https://github.com/rishenko/ex_dice_roller/actions/workflows/ci.yml/badge.svg)](https://github.com/rishenko/ex_dice_roller/actions/workflows/ci.yml)
[![Hex.pm Version](https://img.shields.io/hexpm/v/ex_dice_roller.svg?style=flat)](https://hex.pm/packages/ex_dice_roller)

Provides a [DSL](https://en.wikipedia.org/wiki/Domain-specific_language) and
various options for calculating both simple and complex dice rolling equations.

## Features

Main Features:

* Generates dice rolls with any number of dice and sides of dice.
* Supports common math operators: `+`, `-`, `*`, `/`, `%` modulo, `^` exponentiation
* Supports `+` and `-` unary operators on numbers, such as `-3` or `+2.5`.
* Supports using single-letter variables in expressions, such as `1dx+y`, that
  can be given values upon invocation. Any letter except `d`/`D` can be a
  variable.
* Supports parenthetically grouped expressions such as `(1d4)d(3d6)-(1d4+7)`.
* Supports compiling dice rolls into reusable anonymous functions, or into
  named functions at compile time with `defroll`.
* Introduces a new sigil, `~a`. This can be used as a shorthand for compiling
  and/or rolling dice rolls, such as `~a/1d6+2-(1d4)d6/`.

Other Features:

* Supports dice modifiers in expressions: keep or drop the highest or lowest
  dice (`4d6kh3`, `2d20kl`, `4d6dl1`), rerolls (`1d20r1`, `1d6ro<3`), and
  exploding dice (`3d6!`, or the `:explode` option). `D` works as well as `d`.
* Supports 'keeping' the result of each die roll in an expression. The list
  of values can then be used in a manner similar to list comprehensions in
  expressions with other mathematical operators and lists.
* Optional support for caching compiled rolls. This can be especially useful
  in an application that generates various rolls during runtime.
* Supports filtering final values, such as dropping lowest/highest/both
  (`drop_lowest: true` and more), or filtering using standard comparators (`<=`,
  `>`, and more).


## Installation

Add the latest stable release of `:ex_dice_roller` to your list of dependencies
in `mix.exs`:

```elixir
def deps do
  [
    {:ex_dice_roller, "~> 2.0"}
  ]
end
```

Next, run:
```
$ mix deps.get
```

Please note that the README file reflects the _latest features_ in ExDiceRoller,
whether or not they are available in the _latest release_.


## Configuring

ExDiceRoller has the following configuration properties:

* `:cache_table`: the name of the default cache table, only used with optional
  caching. It is read at compile time, so after changing it, recompile the
  dependency with `mix deps.compile ex_dice_roller --force`.

Example:
```elixir
config :ex_dice_roller,
  cache_table: ExDiceRoller.Cache
```


## General Usage

`ExDiceRoller.roll/2` returns `{:ok, result}`, or
`{:error, %ExDiceRoller.Error{}}` when the expression is invalid or the roll
fails. `ExDiceRoller.roll!/2` returns the bare result and raises
`ExDiceRoller.Error` instead. The examples below use `roll!/2`.

```elixir
iex> ExDiceRoller.roll("1+2")
#=> {:ok, 3}

iex> ExDiceRoller.roll("1/0")
#=> {:error, %ExDiceRoller.Error{reason: :divide_by_zero, message: "the divisor cannot be 0", ...}}

iex> ExDiceRoller.roll!("1/0")
#=> ** (ExDiceRoller.Error) the divisor cannot be 0
```

ExDiceRoller supports a variety of possible dice roll permutations that can be
used in your application.

```elixir
iex> ExDiceRoller.roll!("1+2")
#=> 3

# roll the dice
iex> ExDiceRoller.roll!("1d6")
#=> 1

# rolls of rolls
iex> ExDiceRoller.roll!("1d4d6")    
#=> 10

# complex expressions
iex> ExDiceRoller.roll!("(1d4+2)d((5*6)d20-5)") 
#=> 566

# using variables - variable values can be numbers, string dice roll
# expressions, compiled dice roll functions, or lists of any of those
iex> ExDiceRoller.roll!("1dx+y", [x: 20, y: 13])    
#=> 16

iex> ExDiceRoller.roll!("1dx+y", [x: 20, y: "1d6+8"])    
#=> 15

iex> ExDiceRoller.roll!("1dx+y", [x: [4, 6, 8], y: 13])    
#=> [15, 17, 19]

iex> import ExDiceRoller.Sigil
#=> ExDiceRoller.Sigil
iex> ExDiceRoller.roll!("1dx+y", [x: ~a/2d10/, y: "1d6+8"])
#=> 18

# save each die roll
iex> ExDiceRoller.roll!("3d8", opts: :keep)
#=> [3, 3, 4]

# save each die roll, adding each die's counterpart to the other
iex> ExDiceRoller.roll!("5d1+5d10", opts: :keep)    
#=> [3, 5, 7, 7, 2]

# exploding dice
iex> ExDiceRoller.roll!("1d6", opts: [:explode])
#=> 9

# combine various options
iex> ExDiceRoller.roll!("5d1+5d10", opts: [:keep, :explode])
#=> [7, 3, 2, 4, 10]

# dice modifiers: keep the highest 3 of 4d6, reroll 1s, explode
iex> ExDiceRoller.roll!("4d6kh3")
#=> 14
iex> ExDiceRoller.roll!("4d6kh3", opts: :keep)
#=> [6, 5, 3]
iex> ExDiceRoller.roll!("2D20KL+5")
#=> 9
iex> ExDiceRoller.roll!("1d20r1")
#=> 17
iex> ExDiceRoller.roll!("5d6!", opts: :keep)
#=> [2, 9, 4, 1, 5]

# filter final values before returning them
iex> ExDiceRoller.roll!("8d6", <=: 3, opts: :keep)
#=> [2, 3, 2]
```

## Compiled Expressions

Parsed expressions can be compiled into a single, executable anonymous
function. This function can be reused again and again, with any dice rolls
being randomized and calculated for each call.

```elixir
iex> {:ok, roll_fun} = ExDiceRoller.compile("1d6 - (3d10)d5 + (1d50)/5")
#=> {:ok, #Function<1.86580672/1 in ExDiceRoller.Compiler.build_final_function/1>}

iex> ExDiceRoller.execute!(roll_fun)
#=> -16

iex> roll_fun.([])
#=> -43

iex> {:ok, roll_fun} = ExDiceRoller.compile("1dx+10")
#=> {:ok, #Function<1.86580672/1 in ExDiceRoller.Compiler.build_final_function/1>}

iex> ExDiceRoller.execute!(roll_fun, [x: 5])
#=> 12

iex> ExDiceRoller.execute!(roll_fun, x: "10d100")
#=> 523

iex> ExDiceRoller.execute!(roll_fun, x: "10d100", opts: :keep)
#=> [11, 11, 16, 25, 27, 16, 55, 24, 50, 12]
```

## Sigil Usage

ExDiceRoller introduces a new sigil, `~a`. Without flags it returns a compiled
function. A literal expression is parsed and checked when your code compiles,
so a typo is a compile error, and the compiled function is built only once. Its flags are `r` (roll now), `e` (explode), `k` (keep), `h`
(highest), and `l` (lowest); any flag rolls the expression immediately.
Variables, filters, and caching are not available when the sigil rolls, and
results are bare values (errors raise `ExDiceRoller.Error`).

```elixir
# import the sigil inside any module that will use it
iex> import ExDiceRoller.Sigil
#=> ExDiceRoller.Sigil

# using the sigil without any options will generate a compiled function
iex> fun = ~a/1d6+3/
#=> #Function<1.86580672/1 in ExDiceRoller.Compiler.build_final_function/1>

# the function can be executed like any function from ExDiceRoller.compile/1
iex> ExDiceRoller.execute!(fun)
#=> 6

# compiles the roll and invokes it
iex> ~a/1d2+3/r
#=> 4

# compiles the roll and invokes it with exploding dice
iex> ~a/1d2+2/re
#=> 9

# rolling a compiled function
iex> ExDiceRoller.roll!(~a/2d8-2/)
#=> 3

# keeping dice rolls and adding 5 to each
iex> ~a/5d1+5/k
#=> [6, 6, 6, 6, 6]

# keeping dice rolls from both sides, adding each value to its counterpart
iex> ~a/5d1+5d10/k
#=> [8, 7, 5, 2, 11]
```

## Performance

Compile an expression once and reuse the function: a compiled `1d20+5` rolls
in about 115 ns, roughly 7 million rolls per second on one core. For
expressions fixed in your code, `ExDiceRoller.Roller.defroll/2` generates a
named function at compile time that rolls `1d20+5` in about 40 ns, as fast as
hand-written code. Literal `~a` sigils are parsed when your code compiles,
and `cache: true` avoids re-parsing strings that arrive at run time. See
[the performance guide](guides/performance.md) for measurements and advice,
and run `MIX_ENV=prod mix run bench/rolls.exs` to measure your own hardware.

## Caching Support

The default cache starts with the `:ex_dice_roller` application, so
`cache: true` needs no setup. `ExDiceRoller.start_cache/1` starts more caches
under ExDiceRoller's supervisor; you can also add
`{ExDiceRoller.Cache, name: MyCache}` to your own supervision tree.

```elixir

iex> ExDiceRoller.roll!("xdy-2d4", [x: 10, y: 5, cache: true])
#=> 34

iex> ExDiceRoller.Cache.all()
#=> [{"xdy-2d4", #Function<1.86580672/1 in ExDiceRoller.Compiler.build_final_function/1>}]

iex> ExDiceRoller.roll!("xdy-2d4", [x: 10, y: "2d6", cache: true])
#=> 29

iex> ExDiceRoller.Cache.all()
#=> [{"xdy-2d4", #Function<1.86580672/1 in ExDiceRoller.Compiler.build_final_function/1>}]

iex> ExDiceRoller.roll!("1d6+3d4", cache: true)
#=> 10

iex> ExDiceRoller.Cache.all()
#=> [
#=>   {"xdy-2d4", #Function<1.86580672/1 in ExDiceRoller.Compiler.build_final_function/1>},
#=>   {"1d6+3d4", #Function<1.86580672/1 in ExDiceRoller.Compiler.build_final_function/1>}
#=> ]
```


## How It Works

1. ExDiceRoller uses Erlang's [leex](https://www.erlang.org/doc/apps/parsetools/leex.html)
   to tokenize a dice roll string. A second pass in `ExDiceRoller.Tokenizer`
   turns letters written right after a roll (`kh3`, `r1`) into modifier tokens.
2. The tokens are passed to [yecc](https://www.erlang.org/doc/apps/parsetools/yecc.html),
   which parses them into a syntax tree.
3. `ExDiceRoller.Compiler` walks the tree. Number literals stay numbers; every
   other expression (math, rolls, variables, `,` separators) becomes an
   anonymous function that calls the functions for its sub-expressions.
4. The result is wrapped in a final function that applies options and filters
   and rounds the result.
5. Running that function (`execute/2`, `roll/2`, or calling it directly)
   evaluates the tree, rolling dice as it goes.

```elixir
iex> expr = "(1d4+2.56)d((5*6)d20-5)"
"(1d4+2.56)d((5*6)d20-5)"

iex> {:ok, tokens} = ExDiceRoller.tokenize(expr)
{:ok,
 [
   {:"(", 1, ~c"("},
   {:int, 1, ~c"1"},
   {:roll, 1, ~c"d"},
   {:int, 1, ~c"4"},
   {:basic_operator, 1, ~c"+"},
   {:float, 1, ~c"2.56"},
   {:")", 1, ~c")"},
   {:roll, 1, ~c"d"},
   {:"(", 1, ~c"("},
   {:"(", 1, ~c"("},
   {:int, 1, ~c"5"},
   {:complex_operator, 1, ~c"*"},
   {:int, 1, ~c"6"},
   {:")", 1, ~c")"},
   {:roll, 1, ~c"d"},
   {:int, 1, ~c"20"},
   {:basic_operator, 1, ~c"-"},
   {:int, 1, ~c"5"},
   {:")", 1, ~c")"}
 ]}

iex> {:ok, parse_tree} = ExDiceRoller.parse(tokens)
{:ok,
 {:roll, {{:operator, ~c"+"}, {:roll, 1, 4}, 2.56},
  {{:operator, ~c"-"}, {:roll, {{:operator, ~c"*"}, 5, 6}, 20}, 5}}}

iex> {:ok, roll_fun} = ExDiceRoller.compile(parse_tree)
{:ok, #Function<0.39667494/1 in ExDiceRoller.Compiler.build_final_function/1>}

iex> roll_fun.([])
739

iex> roll_fun.([])
905
```

`ExDiceRoller.Compiler.fun_info/1` shows the nested functions of a compiled
roll, for debugging.


## Contributing

Please refer to CONTRIBUTING.md for more information on how you can contribute
to this project.


## Tooling

* [credo](https://github.com/rrrene/credo) is used for static code analysis.
* Documentation, generated by [ex_doc](https://github.com/elixir-lang/ex_doc),
  is [available at hex.pm](https://hexdocs.pm/ex_dice_roller/). 


## License

ExDiceRoller source code is released under the Apache License 2.0.