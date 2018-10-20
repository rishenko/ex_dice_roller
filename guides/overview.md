# Overview

ExDiceRoller is a library that provides a [DSL](https://en.wikipedia.org/wiki/Domain-specific_language) and various options for calculating both simple and complex dice rolling equations.

## Installing

Add `:ex_dice_roller` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ex_dice_roller, "~> 0.5.0-alpha"}
  ]
end
```

Next, run:
```
$ mix deps.get
```

## Configuring

ExDiceRoller has the following configuration properties:

* `:cache_table`: the name of the cache table used by ExDiceRoller, only used with optional caching

Example:
```elixir
config :ex_dice_roller,
  cache_table: ExDiceRoller.Cache
```

## Usage

The following sections detail how to use ExDiceRoller in any application. Instructions on how to emulate common dice mechanics can be found in [Dice Mechanics](dice_mechanics.html).


## Rolling Dice

Dice rolls can be made using either `ExDiceRoller.roll/3` or using the `~a` sigil.

Example `ExDiceRoller.roll/3` usage:

    iex> ExDiceRoller.roll("1d6")
    6

Example sigil usage:

    iex> import ExDiceRoller.Sigil
    iex> ~a/1d6/r
    5


### Roll Options

ExDiceRoller also supports various options that can be used when executing a dice roll.

    iex> ExDiceRoller.roll("1d6+3", [], [:explode])
    14

The same can be done with the sigil:

    iex> import ExDiceRoller.Sigil
    iex> ~a/1d6+3/e
    17

More detailed information about dice rolls, equations, and options can be seen in `ExDiceRoller` documentation. Option usage with the sigil can be seen in `ExDiceRoller.Sigil`.


## Rolling Dice with Variables

ExDiceRoller also supports single-character variables.

    iex> ExDiceRoller.roll("xdy+xd6", [x: 5, y: 4])
    28

The `~a` sigil does not support variables when executing dice rolls.

    iex> import ExDiceRoller.Sigil
    iex> ~a/xdy+xd6/r
    ** (ArgumentError) no variable 'x' was found in the arguments

However, the `~a` sigil _does_ support generating compiled dice roll equations with variables, as detailed below.


## Compiled Dice Rolls

While repeatedly calling `ExDiceRoller.roll/3` is very fast, it's better to tokenize, parse, and compile a dice roll into a function once, and reuse that function throughout a module or application. ExDiceRoller does that via `ExDiceRoller.compile/1` and `ExDiceRoller.execute/3`.

    iex> {:ok, fun} = ExDiceRoller.compile("2d6+2")
    {:ok, #Function<1.36415363/2 in ExDiceRoller.Compiler.compile/1>}
    iex> ExDiceRoller.execute(fun)
    8

The `~a` sigil can also generate compiled functions, including those with variables.

    iex> import ExDiceRoller.Sigil
    iex> fun = ~a/2d6+2/
    #Function<1.36415363/2 in ExDiceRoller.Compiler.compile/1>
    iex> ExDiceRoller.execute(fun)
    10


## Caching Compiled Dice Rolls

While creating dice roll functions during compile-time and reusing them is great, there are situations when dice rolls need to be built and generated at runtime. Again, ExDiceRoller can do this very quickly, with even complex expressions taking only a tenth of a millisecond. But if every microsecond counts,
ExDiceRoller provides caching.

    iex> ExDiceRoller.start_cache()
    {:ok, ExDiceRoller.Cache}
    iex> ExDiceRoller.roll("1d6+3", [], [:cache])
    4
    iex> ExDiceRoller.Cache.all()
    [{"1d6+3", #Function<1.36415363/2 in ExDiceRoller.Compiler.compile/1>}]
    iex> ExDiceRoller.roll("1d6+3", [], [:cache])
    8
    iex> ExDiceRoller.Cache.all()
    [{"1d6+3", #Function<1.36415363/2 in ExDiceRoller.Compiler.compile/1>}]
    iex> ExDiceRoller.roll("2d10-5+3d6/8", [], [:cache])
    5
    iex> ExDiceRoller.Cache.all()
    [
      {"1d6+3", #Function<1.36415363/2 in ExDiceRoller.Compiler.compile/1>},
      {"2d10-5+3d6/8", #Function<1.36415363/2 in ExDiceRoller.Compiler.compile/1>}
    ]