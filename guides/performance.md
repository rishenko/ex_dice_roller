# Performance

ExDiceRoller turns an expression into a tree of small anonymous functions
once, then runs that tree for every roll. Parsing is the expensive part, so
the main rule is: **parse once, roll many times.**

## Choosing how to roll

From fastest to slowest:

1. **`defroll`, for expressions fixed in your code.** `ExDiceRoller.Roller`
   turns an expression into a named function when your module compiles. The
   generated code is plain Elixir, with no closures to call, and it rolls the
   same results as a compiled function from the same random seed. A call with
   no arguments is as fast as hand-written `:rand.uniform/1` code; a call
   with variables only (no options or filters) is close to it.

        defmodule MyGame.Dice do
          import ExDiceRoller.Roller
          defroll attack, "1d20+x"
        end

        MyGame.Dice.attack(x: 5)

2. **A compiled function you keep.** Call `ExDiceRoller.compile/1` (or
   `compile!/1`) once, at startup or when a rule is loaded, and reuse the
   function. Call it as `fun.(args)` for a bare result, or through
   `ExDiceRoller.execute/2` for `{:ok, result}`.

        {:ok, attack} = ExDiceRoller.compile("1d20+x")
        attack.(x: 5)

3. **The `~a` sigil.** For an expression written in your code, `~a/1d20+5/`
   is parsed and checked when your code compiles; a typo is a compile error.
   The roll function is built the first time the sigil runs and kept in
   `:persistent_term` under a small key computed at compile time, so each
   later use costs one quick lookup, however long the expression. Interpolated
   sigils (`~a/#{n}d6/`) are parsed every time they run.

4. **A cached string.** `ExDiceRoller.roll(expr, cache: true)` looks the
   expression up in an ETS cache and parses it only the first time. Use this
   when expressions arrive as strings at run time, such as from a database or
   from players.

5. **An uncached string.** `ExDiceRoller.roll(expr)` tokenizes, parses, and
   compiles on every call. It is fine for occasional rolls.

## Measurements

Median time per call on an Apple M1 Max (10 cores), Elixir 1.18, OTP 27,
`MIX_ENV=prod`. Expect different absolute numbers on other hardware; the
ratios are what matter.

Call                                        | Time per call
------------------------------------------- | -------------
`:rand.uniform(20) + 5` (hand-written floor) | ~35 ns
`defroll` `1d20+5`, `d20()`                 | ~40 ns
`defroll` `1d20+x`, `d20x(x: 5)`            | ~55 ns
compiled `1d20+5`, `fun.([])`               | ~115 ns
compiled `1d20+5`, `execute!/2`             | ~140 ns
`~a/1d20+5/r`                               | ~170 ns
`roll!("1d20+5", cache: true)`              | ~285 ns
`roll!("1d20+5")`, no cache                 | 1.0–1.7 µs
compiled `4d6kh3`                           | ~850 ns
`defroll` `4d6kh3`                          | ~720 ns
compile `(1d4)d(6*y)-(2/3+1dx)+4d6kh3`      | ~2.8 µs
run that expression, compiled               | ~1.5 µs
run that expression, `defroll`              | ~1.0 µs
run that expression, `roll(cache: true)`    | ~1.9 µs

Throughput:

Roll                | 1 process              | 10 processes
------------------- | ---------------------- | ------------------------
compiled `1d20+5`   | ~7–8 million rolls/s   | ~43–50 million rolls/s
compiled `4d6kh3`   | ~1.3 million rolls/s   | ~8.6 million rolls/s
`defroll` `1d20+5`  | ~23–27 million rolls/s | ~120–145 million rolls/s

So a system making thousands of rolls per second spends well under 1% of
one core on them. Rolls in separate processes run in parallel; each process
has its own random number state, so there is no shared lock.

To measure on your own hardware:

    MIX_ENV=prod mix run bench/rolls.exs

## What costs what

* **Parsing** (tokenize, parse, compile) costs about 10 to 15 times as much
  as running a simple roll. Avoid it in hot paths: compile once, or use the
  sigil or the cache.
* **Each die** costs one call to `:rand.uniform/1`, about 30 ns on top of a
  fixed ~70 ns per roll: `1d6` takes ~100 ns, `10d6` ~410 ns, and `100d6`
  ~3.4 µs.
* **Modifiers** sort the dice (keep/drop) or draw extra dice (rerolls,
  explosions), so `4d6kh3` costs several times `1d20+5`.
* **Options and filters** are read on every call. Passing none (`fun.([])`)
  is the cheapest. A `defroll` function skips that work when it is given
  only variables, so `attack(x: 5)` stays fast; options or filters send it
  down the general path, which costs about what a compiled function does.
* **Keep and drop modifiers** sort the dice, and that work is the same for
  `defroll` and compiled functions, so `defroll` saves less on `4d6kh3` than
  on plain rolls.
* **The cache** adds an ETS lookup (about 150 ns) on top of running the
  compiled function. A function you hold yourself skips it.
* **Variables given as strings** (`x: "1d6"`) are parsed on every call. Pass
  a compiled function (`x: ExDiceRoller.compile!("1d6")`) instead.

## Notes

* Compiled functions and sigils don't fold constant math: `1+2` is
  computed on every call. It is cheap (`1d20+(10/2)` takes ~135 ns against ~115 ns for
  `1d20+5`), but write the constant if you can.
* Each distinct literal sigil expression adds one `:persistent_term` entry
  the first time it runs. That is meant for a fixed set of expressions in
  your code, which is what sigils are. For expressions built at run time, use
  `compile/1` or the cache.
