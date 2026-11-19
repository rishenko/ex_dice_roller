# Overview

ExDiceRoller is a library that provides a [DSL](https://en.wikipedia.org/wiki/Domain-specific_language) and various options for calculating both simple and complex dice rolling equations.

## Installing

Add `:ex_dice_roller` to your list of dependencies in `mix.exs`:

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

## Usage

The following sections detail how to use ExDiceRoller in any application. Instructions on how to emulate common dice mechanics can be found in [Dice Mechanics](dice_mechanics.html).


## Rolling Dice

Dice rolls can be made using `ExDiceRoller.roll/2` (which returns `{:ok, result}`), `ExDiceRoller.roll!/2` (which returns the bare result), or using the `~a` sigil.

Example `ExDiceRoller.roll!/2` usage:

    iex> ExDiceRoller.roll!("1d6")
    6

Example sigil usage:

    iex> import ExDiceRoller.Sigil
    iex> ~a/1d6/r
    5


### Dice Modifiers

Modifiers written right after a roll keep or drop dice, reroll them, or make
them explode:

    iex> ExDiceRoller.roll!("4d6kh3")
    13
    iex> ExDiceRoller.roll!("2d20kl+5", opts: :keep)
    [9]
    iex> ExDiceRoller.roll!("1d20r1")
    17

The full syntax is in `ExDiceRoller.Compilers.Roll`.

### Roll Options

ExDiceRoller also supports various options that can be used when executing a dice roll.

    iex> ExDiceRoller.roll!("1d6+3", opts: [:explode])
    14

The same can be done with the sigil:

    iex> import ExDiceRoller.Sigil
    iex> ~a/1d6+3/e
    17

More detailed information about dice rolls, equations, and options can be seen in `ExDiceRoller` documentation. Option usage with the sigil can be seen in `ExDiceRoller.Sigil`.


## Rolling Dice with Variables

ExDiceRoller also supports single-letter variables (any letter except `d` and `D`).

    iex> ExDiceRoller.roll!("xdy+xd6", [x: 5, y: 4])
    28

The `~a` sigil does not support variables when executing dice rolls.

    iex> import ExDiceRoller.Sigil
    iex> ~a/xdy+xd6/r
    ** (ExDiceRoller.Error) no variable 'x' was found in the arguments

However, the `~a` sigil _does_ support generating compiled dice roll equations with variables, as detailed below.

More detailed information about variables can be found in `ExDiceRoller.Compilers.Variable`.


## Compiled Dice Rolls

While repeatedly calling `ExDiceRoller.roll!/2` is very fast, it's better to tokenize, parse, and compile a dice roll into a function once, and reuse that function throughout a module or application. ExDiceRoller does that via `ExDiceRoller.compile/1` and `ExDiceRoller.execute!/2`.

    iex> {:ok, fun} = ExDiceRoller.compile("2d6+2")
    {:ok, #Function<1.36415363/1 in ExDiceRoller.Compiler.build_final_function/1>}
    iex> ExDiceRoller.execute!(fun)
    8

The `~a` sigil can also generate compiled functions, including those with variables. The sigil parses its expression when your code compiles and builds the function once, so it is as cheap to reuse as a function from `compile/1`.

    iex> import ExDiceRoller.Sigil
    iex> fun = ~a/2d6+2/
    #Function<1.36415363/1 in ExDiceRoller.Compiler.build_final_function/1>
    iex> ExDiceRoller.execute!(fun)
    10

More detailed information about compiling dice roll expressions can be found in `ExDiceRoller.Compiler`.


## Caching Compiled Dice Rolls

While creating dice roll functions during compile-time and reusing them is great, there are situations when dice rolls need to be built and generated at runtime. Again, ExDiceRoller can do this very quickly: tokenizing, parsing, and compiling a complex expression takes a few microseconds. But if every microsecond counts,
ExDiceRoller provides caching. The default cache starts with the application,
so no setup is needed.

    iex> ExDiceRoller.roll!("1d6+3", cache: true)
    4
    iex> ExDiceRoller.Cache.all()
    [{"1d6+3", #Function<1.36415363/1 in ExDiceRoller.Compiler.build_final_function/1>}]
    iex> ExDiceRoller.roll!("1d6+3", cache: true)
    8
    iex> ExDiceRoller.Cache.all()
    [{"1d6+3", #Function<1.36415363/1 in ExDiceRoller.Compiler.build_final_function/1>}]
    iex> ExDiceRoller.roll!("2d10-5+3d6/8", cache: true)
    5
    iex> ExDiceRoller.Cache.all()
    [
      {"1d6+3", #Function<1.36415363/1 in ExDiceRoller.Compiler.build_final_function/1>},
      {"2d10-5+3d6/8", #Function<1.36415363/1 in ExDiceRoller.Compiler.build_final_function/1>}
    ]

More detailed information can be found in `ExDiceRoller.Cache`.
