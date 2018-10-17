defmodule ExDiceRoller.Compilers.Roll do
  @moduledoc """
  Handles compiling dice roll expressions.

      iex> expr = "1d6"
      "1d6"
      iex> {:ok, tokens} = ExDiceRoller.Tokenizer.tokenize(expr)
      {:ok, [{:digit, 1, '1'}, {:roll, 1, 'd'}, {:digit, 1, '6'}]}
      iex> {:ok, parse_tree} = ExDiceRoller.Parser.parse(tokens)
      {:ok, {:roll, {:digit, 1}, {:digit, 6}}}
      iex> fun = ExDiceRoller.Compilers.Roll.compile(parse_tree)
      iex> fun.([], [])
      3
      iex> fun.([], [])
      2

  ## Options

  ### Exploding Dice

  Some systems use a dice mechanic known as 'exploding dice'. The mechanic works
  as follows:

  1. a multi-sided die, in this case a six-sided die, is rolled
  2. if the value is anything other than six, they record the result and skip
  to step 5
  3. if the value is six, the result is recorded, and the die is rolled again
  4. steps 1 and 3 are repeated until step 2 is reached
  5. the sum total result of all rolls is recorded and used

  You can utilize this mechanic by specifying the `:explode` option for
  ExDiceRoller.roll/3 calls, or specifying the `e` flag when using the `~a`
  sigil. This option can be used with any ExDiceRoller roll option.

  It should also be noted that the exploding dice mechanic is not applied to a
  one-sided die, since that would result in an infinite loop.

  Examples:

      iex> expr = "1d6"
      "1d6"
      iex> {:ok, tokens} = ExDiceRoller.Tokenizer.tokenize(expr)
      {:ok, [{:digit, 1, '1'}, {:roll, 1, 'd'}, {:digit, 1, '6'}]}
      iex> {:ok, parse_tree} = ExDiceRoller.Parser.parse(tokens)
      {:ok, {:roll, {:digit, 1}, {:digit, 6}}}
      iex> fun = ExDiceRoller.Compilers.Roll.compile(parse_tree)
      iex> fun.([], [:explode])
      3
      iex> fun.([], [:explode])
      2
      iex> fun.([], [:explode])
      10

      iex> import ExDiceRoller.Sigil
      iex> ~a/1d10/re
      9
      iex> ~a/1d10/re
      14


  ### Keeping Dice Rolls

  A batch of dice being rolled can be returned as either their sum total, or
  as individual results. The former is the default handling of rolls by
  ExDiceRoller. The latter, keeping each die rolled, requires the option
  `:keep`. Note that a list of die roll results will be returned when using the
  `:keep` option.

      iex> expr = "5d6"
      "5d6"
      iex> {:ok, tokens} = ExDiceRoller.Tokenizer.tokenize(expr)
      {:ok, [{:digit, 1, '5'}, {:roll, 1, 'd'}, {:digit, 1, '6'}]}
      iex> {:ok, parse_tree} = ExDiceRoller.Parser.parse(tokens)
      {:ok, {:roll, {:digit, 5}, {:digit, 6}}}
      iex> fun = ExDiceRoller.Compilers.Roll.compile(parse_tree)
      iex> fun.([], [:keep])
      [3, 2, 6, 4, 5]


  #### Kept Rolls and List Comprehensions

  ExDiceroller also has a certain amount of list comprehension support when
  calculating dice roll equations and 'keeping' rolls. The default behavior when
  working with kept rolls is as follows:

  1. If one side of an expression is a list, and the other a value, the action
  will apply the value to each value in the list.
  2. If both sides of an expression are lists, the values of each list are
  applied to their counterpart in the other list. An error is raised if the
  lengths of the two lists are different.
  3. Combination rolls, such as `3d5d6`, will perform each roll expressions in
  succession. Kept values from each roll expression is then used as the number
  of sides in the succeeding expression.

  Example of one side of an expression being a kept list and the other a value:

      iex> {:ok, fun} = ExDiceRoller.compile("5d6+11")
      iex> fun.([], [:keep])
      [14, 13, 17, 15, 16]

  Example of both sides being lists:

      iex> {:ok, fun} = ExDiceRoller.compile("5d6+(5d10+20)")
      iex> fun.([], [:keep])
      [25, 32, 34, 30, 26]

  Example of dice rolls of dice rolls:

      iex> ExDiceRoller.roll("1d1d4", [], [:keep])
      [1]
      iex> ExDiceRoller.roll("2d1d4", [], [:keep])
      [4, 2]
      iex> ExDiceRoller.roll("2d6d4", [], [:keep])
      [2, 4, 4, 2, 3, 2, 4, 4, 4]
  """

  @behaviour ExDiceRoller.Compiler
  alias ExDiceRoller.Compiler

  @impl true
  def compile({:roll, left_expr, right_expr}) do
    compile_roll(Compiler.delegate(left_expr), Compiler.delegate(right_expr))
  end

  @spec compile_roll(Compiler.compiled_val(), Compiler.compiled_val()) :: Compiler.compiled_fun()

  defp compile_roll(num, sides) when is_function(num) and is_function(sides) do
    fn args, opts -> roll_prep(num.(args, opts), sides.(args, opts), opts) end
  end

  defp compile_roll(num, sides) when is_function(num),
    do: fn args, opts -> roll_prep(num.(args, opts), sides, opts) end

  defp compile_roll(num, sides) when is_function(sides),
    do: fn args, opts -> roll_prep(num, sides.(args, opts), opts) end

  defp compile_roll(num, sides),
    do: fn _args, opts -> roll_prep(num, sides, opts) end

  @spec roll_prep(number, number, list(atom | tuple)) :: integer

  defp roll_prep(0, _, _), do: 0
  defp roll_prep(_, 0, _), do: 0

  defp roll_prep(num, sides, opts) when num >= 0 and sides >= 0 do
    num = Compiler.round_val(num)
    sides = Compiler.round_val(sides)
    explode? = :explode in opts

    case :keep in opts do
      true ->
        keep_roll(num, sides, explode?)

      false ->
        Enum.reduce(1..num, 0, fn _, total ->
          total + roll(sides, explode?)
        end)
    end
  end

  defp roll_prep(_, _, _),
    do: raise(ArgumentError, "neither number of dice nor number of sides cannot be less than 0")

  @spec roll(integer, boolean) :: integer

  defp roll(sides, false) do
    Enum.random(1..sides)
  end

  defp roll(sides, true) do
    result = Enum.random(1..sides)
    explode_roll(sides, result, result)
  end

  @spec explode_roll(integer, integer, integer) :: integer

  defp explode_roll(_, 1, acc), do: acc

  defp explode_roll(sides, sides, acc) do
    result = Enum.random(1..sides)
    explode_roll(sides, result, acc + result)
  end

  defp explode_roll(_, _, acc), do: acc

  @spec keep_roll(Compiler.calculated_val(), Compiler.calculated_val(), boolean) ::
          Compiler.calculated_val()

  defp keep_roll(num, sides, explode?) when is_number(num) do
    keep_roll([num], sides, explode?)
  end

  defp keep_roll(num, sides, explode?) when is_number(sides) do
    keep_roll(num, [sides], explode?)
  end

  defp keep_roll(num, sides, explode?) do
    Enum.flat_map(num, fn n ->
      Enum.flat_map(1..n, fn _ ->
        Enum.map(sides, &roll(&1, explode?))
      end)
    end)
  end
end
