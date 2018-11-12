# ExDiceRoller

[![Build Status](https://travis-ci.org/rishenko/ex_dice_roller.svg?branch=master)](https://travis-ci.org/rishenko/ex_dice_roller)
[![Coverage Status](https://coveralls.io/repos/github/rishenko/ex_dice_roller/badge.svg?branch=master)](https://coveralls.io/github/rishenko/ex_dice_roller?branch=master)
[![Hex.pm Version](https://img.shields.io/hexpm/v/ex_dice_roller.svg?style=flat)](https://hex.pm/packages/ex_dice_roller)

Provides a [DSL](https://en.wikipedia.org/wiki/Domain-specific_language) and
various options for calculating both simple and complex dice rolling equations.

## Features

Main Features:

* Generates dice rolls with any number of dice and sides of dice.
* Supports common math operators: `+`, `-`, `*`, `/`, `%` modulo, `^` exponentiation
* Supports `+` and `-` unary operators.
* Supports using single-letter variables in expressions, such as `1dx+y`, that
  can be given values upon invocation.
* Supports parenthetically grouped expressions such as `(1d4)d(3d6)-(1d4+7)`.
* Supports compiling dice rolls into reuseable anonymous functions.
* Introduces a new sigil, `~a`. This can be used as a shorthand for compiling
  and/or rolling dice rolls, such as `~a/1d6+2-(1d4)d6/`.

Other Features:

* Supports exploding dice.
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
    {:ex_dice_roller, "~> 1.0.0-rc.2"}
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

* `:cache_table`: the name of the cache table used by ExDiceRoller, only used with optional caching

Example:
```elixir
config :ex_dice_roller,
  cache_table: ExDiceRoller.Cache
```


## General Usage

ExDiceRoller supports a variety of possible dice roll permutations that can be
used in your application.

```elixir
iex> ExDiceRoller.roll("1+2")
#=> 3

# roll the dice
iex> ExDiceRoller.roll("1d6")
#=> 1

# rolls of rolls
iex> ExDiceRoller.roll("1d4d6")    
#=> 10

# complex expressions
iex> ExDiceRoller.roll("(1d4+2)d((5*6)d20-5)") 
#=> 566

# using variables - variable values can be numbers, string dice roll
# expressions, compiled dice roll functions, or lists of any of those
iex> ExDiceRoller.roll("1dx+y", [x: 20, y: 13])    
#=> 16

iex> ExDiceRoller.roll("1dx+y", [x: 20, y: "1d6+8"])    
#=> 15

iex> ExDiceRoller.roll("1dx+y", [x: [4, 6, 8], y: 13])    
#=> [15, 17, 19]

iex> import ExDiceRoller.Sigil
#=> ExDiceRoller.Sigil
iex> ExDiceRoller.roll("1dx+y", [x: ~a/2d10/, y: "1d6+8"])
#=> 18

# save each die roll
iex> ExDiceRoller.roll("3d8", opts: :keep)
#=> [3, 3, 4]

# save each die roll, adding each die's counterpart to the other
iex> ExDiceRoller.roll("5d1+5d10", opts: :keep)    
#=> [3, 5, 7, 7, 2]

# exploding dice
iex> ExDiceRoller.roll("1d6", opts: [:explode])
#=> 9

# combine various options
iex> ExDiceRoller.roll("5d1+5d10", opts: [:keep, :explode])
#=> [7, 3, 2, 4, 10]

# filter final values before returning them
iex> ExDiceRoller.roll("8d6", <=: 3, opts: :keep)
#=> [2, 3, 2]
```

## Compiled Expressions

Parsed expressions can be compiled into a single, executable anonymous
function. This function can be reused again and again, with any dice rolls
being randomized and calculated for each call.

```elixir
iex> {:ok, roll_fun} = ExDiceRoller.compile("1d6 - (3d10)d5 + (1d50)/5")
#=> {:ok, #Function<1.86580672/2 in ExDiceRoller.Compiler.build_final_function/1>}

iex> ExDiceRoller.execute(roll_fun)
#=> -16

iex> roll_fun.([])
#=> -43

iex> {:ok, roll_fun} = ExDiceRoller.compile("1dx+10")
#=> {:ok, #Function<8.36233920/1 in ExDiceRoller.Compiler.build_final_function/1>}

iex> ExDiceRoller.execute(roll_fun, [x: 5])
#=> 12

iex> ExDiceRoller.execute(roll_fun, x: "10d100")
#=> 523

iex> ExDiceRoller.execute(roll_fun, x: "10d100", opts: :keep)
#=> [11, 11, 16, 25, 27, 16, 55, 24, 50, 12]
```

## Sigil Usage

ExDiceRoller introduces a new sigil, `~a`, with the same set of options as `ExDiceRoller.roll/2`.

```elixir
# import the sigil inside any module that will use it
iex> import ExDiceRoller.Sigil
#=> ExDiceRoller.Sigil

# using the sigil without any options will generate a compiled function
iex> fun = ~a/1d6+3/
#=> #Function<1.86580672/2 in ExDiceRoller.Compiler.build_final_function/1>

# the function can then be executed as any other ExDiceRoller.compile/1
iex> ExDiceRoller.execute(fun)
#=> 6

# compiles the roll and invokes it
iex> ~a/1d2+3/r
#=> 4

# compiles the roll and invokes it with exploding dice
iex> ~a/1d2+2/re
#=> 9

# rolling a compiled function
iex> ExDiceRoller.roll(~a/2d8-2/)
#=> 3

# keeping dice rolls and adding 5 to each
iex> ~a/5d1+5/k
#=> [6, 6, 6, 6, 6]

# keeping dice rolls from both sides, adding each value to its counterpart
iex> ~a/5d1+5d10/k
#=> [8, 7, 5, 2, 11]
```

## Caching Support

```elixir
iex> ExDiceRoller.start_cache()
#=> {:ok, ExDiceRoller.Cache}

iex> ExDiceRoller.roll("xdy-2d4", [x: 10, y: 5, cache: true])
#=> 34

iex> ExDiceRoller.Cache.all()
#=> [{"xdy-2d4", #Function<1.86580672/2 in ExDiceRoller.Compiler.build_final_function/1>}]

iex> ExDiceRoller.roll("xdy-2d4", [x: 10, y: "2d6", cache: true])
#=> 29

iex> ExDiceRoller.Cache.all()
#=> [{"xdy-2d4", #Function<1.86580672/2 in ExDiceRoller.Compiler.build_final_function/1>}]

iex> ExDiceRoller.roll("1d6+3d4", cache: true)
#=> 10

iex> ExDiceRoller.Cache.all()
#=> [
#=>   {"xdy-2d4", #Function<1.86580672/2 in ExDiceRoller.Compiler.build_final_function/1>},
#=>   {"1d6+3d4", #Function<1.86580672/2 in ExDiceRoller.Compiler.build_final_function/1>}
#=> ]
```


## How It Works

1. ExDiceRoller utilizes Erlang's [leex](http://erlang.org/doc/man/leex.html)
   library to tokenize a given dice roll string.
2. The tokens are then passed to [yecc](http://erlang.org/doc/man/yecc.html)
   which parses the tokens into a concrete syntax tree.
3. The syntax tree is then interpreted through recursive navigation.
4. During interpretation:
    1. Any basic numerical values are calculated.
    2. Any dice rolls are converted into anonymous functions.
    3. Any mathematical operations using numbers are calculated.
    4. Any mathematical operations using expressions are converted into
       anonymous functions.
  dice rolls are converted into anonymous functions.
5. The results of interpretation are then wrapped by a final anonymous
function.
6. This final anonymous function is then executed and the value returned.

```elixir
iex> expr = "(1d4+2.56)d((5*6)d20-5)"
"(1d4+2)d((5*6)d20-5)"

iex> {:ok, tokens} = ExDiceRoller.tokenize(expr)
{:ok,
[
  {:"(", 1, '('},
  {:int, 1, '1'},
  {:roll, 1, 'd'},
  {:int, 1, '4'},
  {:basic_operator, 1, '+'},
  {:float, 1, '2.56'},
  {:")", 1, ')'},
  {:roll, 1, 'd'},
  {:"(", 1, '('},
  {:"(", 1, '('},
  {:int, 1, '5'},
  {:complex_operator, 1, '*'},
  {:int, 1, '6'},
  {:")", 1, ')'},
  {:roll, 1, 'd'},
  {:int, 1, '20'},
  {:basic_operator, 1, '-'},
  {:int, 1, '5'},
  {:")", 1, ')'}
]}

iex> {:ok, parse_tree} = ExDiceRoller.parse(tokens)
{:ok,
{:roll,
  {{:operator, '+'},
    {:roll, 1, 4},
    2.56},
  {{:operator, '-'},
    {:roll, 
      {{:operator, '*'}, 5, 6},
      20},
    5}}}

iex> {:ok, roll_fun} = ExDiceRoller.compile(parse_tree)
{:ok, #Function<12.11371143/0 in ExDiceRoller.Compiler.build_final_function/1>}

iex(7)> roll_fun.([])
739

iex(8)> roll_fun.([])
905

iex(9)> ExDiceRoller.Compiler.fun_info(roll_fun)
{#Function<0.37627644/1 in ExDiceRoller.Compilers.Roll.compile_roll/2>,
 :"-compile_roll/2-fun-0-",
 [
   {#Function<1.102777967/1 in ExDiceRoller.Compilers.Math.compile_add/2>,
    :"-compile_add/2-fun-3-",
    [
      {#Function<3.37627644/1 in ExDiceRoller.Compilers.Roll.compile_roll/2>,
       :"-compile_roll/2-fun-3-", [1, 4]},
      2.56
    ]},
   {#Function<21.102777967/1 in ExDiceRoller.Compilers.Math.compile_sub/2>,
    :"-compile_sub/2-fun-3-",
    [
      {#Function<1.37627644/1 in ExDiceRoller.Compilers.Roll.compile_roll/2>,
       :"-compile_roll/2-fun-1-",
       [
         {#Function<19.102777967/1 in ExDiceRoller.Compilers.Math.compile_mul/2>,
          :"-compile_mul/2-fun-7-", [5, 6]},
         20
       ]},
      5
    ]}
 ]}
```


## Contributing

Please refer to CONTRIBUTING.md for more information on how you can contribute
to this project.


## Test Coverage and More

* [ex_coveralls](https://github.com/parroty/excoveralls) provides test coverage
  metrics.
* [credo](https://github.com/rrrene/credo) is used for static code analysis.
* Documentation, generated by [ex_doc](https://github.com/elixir-lang/ex_doc),
  is [available at hex.pm](https://hexdocs.pm/ex_dice_roller/). 


## License

ExDiceRoller source code is released under Apache 2 License.