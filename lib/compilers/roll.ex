defmodule ExDiceRoller.Compilers.Roll do
  @moduledoc """
  Handles compiling dice roll expressions.

      iex> expr = "1d6"
      "1d6"
      iex> {:ok, tokens} = ExDiceRoller.Tokenizer.tokenize(expr)
      {:ok, [{:int, 1, ~c"1"}, {:roll, 1, ~c"d"}, {:int, 1, ~c"6"}]}
      iex> {:ok, parse_tree} = ExDiceRoller.Parser.parse(tokens)
      {:ok, {:roll, 1, 6}}
      iex> fun = ExDiceRoller.Compilers.Roll.compile(parse_tree)
      iex> fun.([])
      3
      iex> fun.([])
      2

  ## Exploding Dice

  Some systems use a dice mechanic known as 'exploding dice'. The mechanic works
  as follows:

  1. a multi-sided die, in this case a six-sided die, is rolled
  2. if the value is anything other than six, they record the result and skip
  to step 5
  3. if the value is six, the result is recorded, and the die is rolled again
  4. steps 1 and 3 are repeated until step 2 is reached
  5. the sum total result of all rolls is recorded and used

  You can utilize this mechanic by specifying the `:explode` option for
  ExDiceRoller.roll/2 calls, or specifying the `e` flag when using the `~a`
  sigil. This option can be used with any ExDiceRoller roll option.

  It should also be noted that the exploding dice mechanic is not applied to a
  one-sided die, since that would result in an infinite loop.

  Examples:

      iex> expr = "1d6"
      "1d6"
      iex> {:ok, tokens} = ExDiceRoller.Tokenizer.tokenize(expr)
      {:ok, [{:int, 1, ~c"1"}, {:roll, 1, ~c"d"}, {:int, 1, ~c"6"}]}
      iex> {:ok, parse_tree} = ExDiceRoller.Parser.parse(tokens)
      {:ok, {:roll, 1, 6}}
      iex> fun = ExDiceRoller.Compilers.Roll.compile(parse_tree)
      iex> fun.(opts: [:explode])
      3
      iex> fun.(opts: [:explode])
      2
      iex> fun.(opts: [:explode])
      10

      iex> import ExDiceRoller.Sigil
      iex> ~a/1d10/re
      9
      iex> ~a/1d10/re
      14


  ## Keeping Dice Rolls

  A batch of dice being rolled can be returned as either their sum total, or
  as individual results. The former is the default handling of rolls by
  ExDiceRoller. The latter, keeping each die rolled, requires the option
  `:keep`. Note that a list of die roll results will be returned when using the
  `:keep` option.

      iex> expr = "5d6"
      "5d6"
      iex> {:ok, tokens} = ExDiceRoller.Tokenizer.tokenize(expr)
      {:ok, [{:int, 1, ~c"5"}, {:roll, 1, ~c"d"}, {:int, 1, ~c"6"}]}
      iex> {:ok, parse_tree} = ExDiceRoller.Parser.parse(tokens)
      {:ok, {:roll, 5, 6}}
      iex> fun = ExDiceRoller.Compilers.Roll.compile(parse_tree)
      iex> fun.(opts: [:keep])
      [3, 2, 6, 4, 5]


  ### Kept Rolls and List Comprehensions

  Kept rolls also support list comprehensions. See
  `ExDiceRoller.ListComprehension` for more information.


  ## Dice Modifiers

  Modifiers are written directly after a roll's sides, and apply to that roll
  only. Letters are case-insensitive (`4D6KH3` works), and `d` may also be
  written `D`.

  Modifier          | Meaning
  ----------------- | ------------------------------------------------------
  `khN` or `kN`     | keep the highest N dice
  `klN`             | keep the lowest N dice
  `dhN`             | drop the highest N dice
  `dlN`             | drop the lowest N dice
  `rN`, `r<N`, ...  | reroll a die until it no longer matches
  `roN`, `ro<N`, ...| reroll a matching die once, and keep the second result
  `!`               | explode, the same as the `:explode` option

  * Counts are whole numbers and default to 1, so `2d20kh` rolls with
  advantage and `2d20kl` with disadvantage.
  * Reroll targets are whole numbers, optionally after a comparator: `=`, `<`,
  `>`, `<=`, or `>=` (`r1` means `r=1`). A roll can have several (`r1r2`).
  Rerolls apply to every die drawn, including the extra dice from explosions.
  Conditions that match every face, such as `1d6r<7`, return an error with
  reason `:invalid_modifier`.
  * Rerolls and explosions happen as each die is rolled. Keep and drop then
  apply in the order written (`6d6kh4dl1`). Kept dice stay in the order they
  were rolled, and ties go to the die rolled first.
  * Without the `:keep` option the kept dice are summed; with it, they are
  returned as a list.
  * Outside modifier position, letters are variables as usual: `k+r` adds two
  variables, and `2dh` rolls two dice with `h` sides.

      iex> ExDiceRoller.roll!("4d6kh3", opts: :keep) |> length()
      3
      iex> ExDiceRoller.roll!("2d20kl", opts: :keep) |> length()
      1
      iex> ExDiceRoller.roll!("4d6dl1+2") in 5..20
      true
      iex> ExDiceRoller.roll!("1d20r1") in 2..20
      true
      iex> ExDiceRoller.roll!("1D6") in 1..6
      true
      iex> {:error, %ExDiceRoller.Error{reason: :invalid_modifier}} = ExDiceRoller.roll("1d6r<7")

  """

  @behaviour ExDiceRoller.Compiler
  alias ExDiceRoller.{Args, Compiler, Error, ListComprehension, Tokenizer}

  @impl true
  def compile({:roll, left_expr, right_expr}) do
    compile_roll(Compiler.delegate(left_expr), Compiler.delegate(right_expr), [])
  end

  def compile({:roll, left_expr, right_expr, modifiers}) do
    compile_roll(Compiler.delegate(left_expr), Compiler.delegate(right_expr), modifiers)
  end

  @spec compile_roll(Compiler.compiled_val(), Compiler.compiled_val(), [Tokenizer.modifier()]) ::
          Compiler.compiled_fun()

  defp compile_roll(num, sides, mods) when is_function(num) and is_function(sides) do
    fn args -> roll_prep(num.(args), sides.(args), mods, args) end
  end

  defp compile_roll(num, sides, mods) when is_function(num),
    do: fn args -> roll_prep(num.(args), sides, mods, args) end

  defp compile_roll(num, sides, mods) when is_function(sides),
    do: fn args -> roll_prep(num, sides.(args), mods, args) end

  defp compile_roll(num, sides, mods),
    do: fn args -> roll_prep(num, sides, mods, args) end

  @spec roll_prep(
          Compiler.calculated_val(),
          Compiler.calculated_val(),
          [Tokenizer.modifier()],
          list(atom | tuple)
        ) :: Compiler.calculated_val()
  defp roll_prep(num, sides, mods, args) do
    keep? = Args.has_option?(args, :keep)
    explode? = Args.has_option?(args, :explode)
    __roll__(num, sides, explode?, keep?, mods)
  end

  @doc false
  # Rolls with dice counts and sides that may be lists. Used by compiled
  # closures and by `ExDiceRoller.Roller`.
  @spec __roll__(
          Compiler.calculated_val(),
          Compiler.calculated_val(),
          boolean,
          boolean,
          [Tokenizer.modifier()]
        ) :: Compiler.calculated_val()
  def __roll__(num, sides, explode?, keep?, mods) do
    ListComprehension.flattened_apply(num, sides, explode?, fn n, s, e? ->
      roll_dice(n, s, e?, keep?, mods)
    end)
  end

  @doc false
  # `__roll__/5` for a number of dice and sides that are both numbers.
  @spec __roll_dice__(number, number, boolean, boolean, [Tokenizer.modifier()]) ::
          integer | list(integer)
  def __roll_dice__(n, s, explode?, keep?, mods), do: roll_dice(n, s, explode?, keep?, mods)

  # Rolls `n` dice with `s` sides. The checks run on each die group, after
  # list expansion, so they also cover values from variables and kept rolls.
  @spec roll_dice(number, number, boolean, boolean, [Tokenizer.modifier()]) ::
          integer | list(integer)
  defp roll_dice(n, s, _, _, _) when n < 0 or s < 0 do
    raise Error,
      reason: :negative_dice,
      message: "neither number of dice nor number of sides can be less than 0"
  end

  defp roll_dice(n, s, explode?, keep?, mods) do
    n = Compiler.round_val(n)
    s = Compiler.round_val(s)
    explode? = explode? or :explode in mods

    cond do
      # no dice rolled (including counts that round down to 0)
      n == 0 -> finish([], mods, keep?)
      # zero-sided dice always total 0; with keep, a single 0 stands for them
      s == 0 -> finish([0], mods, keep?)
      # the common case: a plain sum, without building a list
      mods == [] and not keep? -> Enum.reduce(1..n, 0, fn _, acc -> acc + die(s, explode?) end)
      true -> n |> draw_dice(s, explode?, mods) |> finish(mods, keep?)
    end
  end

  # applies keep/drop modifiers, then sums unless the dice are kept
  defp finish(dice, mods, keep?) do
    dice = Enum.reduce(mods, dice, &select/2)
    if keep?, do: dice, else: Enum.sum(dice)
  end

  # rolls `n` dice, applying rerolls to every draw (explosions included)
  defp draw_dice(n, s, explode?, mods) do
    always = for {:reroll, :always, cmp, t} <- mods, do: {cmp, t}
    once = for {:reroll, :once, cmp, t} <- mods, do: {cmp, t}
    check_rerolls!(s, always, explode?)

    if always == [] and once == [] do
      Enum.map(1..n, fn _ -> die(s, explode?) end)
    else
      draw = fn -> draw(s, always, once) end
      Enum.map(1..n, fn _ -> die(s, explode?, draw) end)
    end
  end

  # One die, with its explosions added. `draw` is `:plain` for a bare
  # `:rand.uniform/1` (no closure call), or a function that applies rerolls.
  defp die(s, false), do: :rand.uniform(s)
  defp die(s, true), do: die(s, true, :plain)

  defp die(s, false, draw), do: next(draw, s)

  defp die(s, true, draw) do
    first = next(draw, s)
    explode_draws(s, first, first, draw)
  end

  defp next(:plain, s), do: :rand.uniform(s)
  defp next(draw, _s), do: draw.()

  defp draw(s, always, once) do
    value = reroll_always(s, always)

    if matches?(value, once),
      do: reroll_always(s, always),
      else: value
  end

  defp reroll_always(s, conditions) do
    value = :rand.uniform(s)
    if matches?(value, conditions), do: reroll_always(s, conditions), else: value
  end

  defp explode_draws(s, s, acc, draw) when s > 1 do
    value = next(draw, s)
    explode_draws(s, value, acc + value, draw)
  end

  defp explode_draws(_, _, acc, _), do: acc

  defp matches?(value, conditions), do: Enum.any?(conditions, &compare(value, &1))

  defp compare(v, {:==, t}), do: v == t
  defp compare(v, {:<, t}), do: v < t
  defp compare(v, {:>, t}), do: v > t
  defp compare(v, {:<=, t}), do: v <= t
  defp compare(v, {:>=, t}), do: v >= t

  # A face that no `r` condition matches must exist, or rerolling never ends.
  # When exploding, a face other than the highest must exist too, or the die
  # explodes forever. The matching faces form a union of intervals, so if a
  # face survives, one survives at an interval boundary; only those are checked.
  defp check_rerolls!(_, [], _), do: :ok

  defp check_rerolls!(s, always, explode?) do
    candidates =
      [1, s | Enum.flat_map(always, fn {_, t} -> [t - 1, t, t + 1] end)]
      |> Enum.filter(&(&1 >= 1 and &1 <= s))
      |> Enum.reject(&matches?(&1, always))

    cond do
      candidates == [] ->
        raise Error,
          reason: :invalid_modifier,
          details: always,
          message: "reroll conditions match every face of a d#{s}, so rerolling would never end"

      explode? and s > 1 and Enum.all?(candidates, &(&1 == s)) ->
        raise Error,
          reason: :invalid_modifier,
          details: always,
          message:
            "reroll conditions leave only #{s} on a d#{s}, so the die would explode forever"

      true ->
        :ok
    end
  end

  # Keep/drop, applied in the order written; kept dice stay in rolled order.
  # Ranks the dice by value, with ties going to the die rolled first, takes
  # the first `count` positions, then walks the dice once to keep or drop
  # those positions. Dice are integers, so each die's rank and position are
  # packed into one integer, `rank * size + position`, which sorts like the
  # pair (positions are below `size`) and faster than tuples.
  defp select({kind, which, count}, dice) when kind in [:keep, :drop] do
    size = length(dice)

    chosen =
      dice
      |> Enum.with_index(fn v, i -> rank(which, v) * size + i end)
      |> :lists.sort()
      |> Enum.take(count)
      |> Enum.map(&Integer.mod(&1, size))
      |> :lists.sort()

    pick(dice, 0, chosen, kind == :keep, [])
  end

  defp select(_, dice), do: dice

  defp rank(:highest, v), do: -v
  defp rank(:lowest, v), do: v

  # walks the dice; `chosen` holds the chosen positions in ascending order
  defp pick([], _, _, _, acc), do: Enum.reverse(acc)

  defp pick([die | rest], i, [i | chosen], keep?, acc),
    do: pick(rest, i + 1, chosen, keep?, if(keep?, do: [die | acc], else: acc))

  defp pick([die | rest], i, chosen, keep?, acc),
    do: pick(rest, i + 1, chosen, keep?, if(keep?, do: acc, else: [die | acc]))
end
