defmodule ExDiceRoller.Compilers.Roll do
  @moduledoc """
  Handles compiling dice roll expressions.

      iex> expr = "1d6"
      "1d6"
      iex> {:ok, tokens} = ExDiceRoller.Tokenizer.tokenize(expr)
      {:ok, [{:int, 1, '1'}, {:roll, 1, 'd'}, {:int, 1, '6'}]}
      iex> {:ok, parse_tree} = ExDiceRoller.Parser.parse(tokens)
      {:ok, {:roll, 1, 6}}
      iex> fun = ExDiceRoller.Compilers.Roll.compile(parse_tree)
      iex> fun.([])
      3
      iex> fun.([])
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
      {:ok, [{:int, 1, '1'}, {:roll, 1, 'd'}, {:int, 1, '6'}]}
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


  ### Keeping Dice Rolls

  A batch of dice being rolled can be returned as either their sum total, or
  as individual results. The former is the default handling of rolls by
  ExDiceRoller. The latter, keeping each die rolled, requires the option
  `:keep`. Note that a list of die roll results will be returned when using the
  `:keep` option.

      iex> expr = "5d6"
      "5d6"
      iex> {:ok, tokens} = ExDiceRoller.Tokenizer.tokenize(expr)
      {:ok, [{:int, 1, '5'}, {:roll, 1, 'd'}, {:int, 1, '6'}]}
      iex> {:ok, parse_tree} = ExDiceRoller.Parser.parse(tokens)
      {:ok, {:roll, 5, 6}}
      iex> fun = ExDiceRoller.Compilers.Roll.compile(parse_tree)
      iex> fun.(opts: [:keep])
      [3, 2, 6, 4, 5]


  #### Kept Rolls and List Comprehensions


  """

  @behaviour ExDiceRoller.Compiler
  alias ExDiceRoller.{Compiler, ListComprehension}

  @impl true
  def compile({:roll, left_expr, right_expr}) do
    compile_roll(Compiler.delegate(left_expr), Compiler.delegate(right_expr))
  end

  @spec compile_roll(Compiler.compiled_val(), Compiler.compiled_val()) :: Compiler.compiled_fun()

  defp compile_roll(num, sides) when is_function(num) and is_function(sides) do
    fn args -> roll_prep(num.(args), sides.(args), args) end
  end

  defp compile_roll(num, sides) when is_function(num),
    do: fn args -> roll_prep(num.(args), sides, args) end

  defp compile_roll(num, sides) when is_function(sides),
    do: fn args -> roll_prep(num, sides.(args), args) end

  defp compile_roll(num, sides),
    do: fn args -> roll_prep(num, sides, args) end

  @spec roll_prep(Compiler.calculated_val, Compiler.calculated_val, list(atom | tuple)) :: integer

  defp roll_prep(0, _, _), do: 0
  defp roll_prep(_, 0, _), do: 0

  defp roll_prep(n, s, _) when n < 0 or s < 0 do
    raise(ArgumentError, "neither number of dice nor number of sides can be less than 0")
  end

  defp roll_prep(num, sides, args) do
    num = Compiler.round_val(num)
    sides = Compiler.round_val(sides)
    explode? = :explode in Keyword.get(args, :opts, [])

    fun =
      case :keep in Keyword.get(args, :opts, []) do
        true -> keep_roll()
        false -> normal_roll()
      end

    ListComprehension.flattened_apply(num, sides, explode?, fun)
  end

  defp keep_roll do
    fn n, s, e? -> Enum.map(1..n, fn _ -> roll(s, e?) end) end
  end

  defp normal_roll do
    fn n, s, e? -> Enum.reduce(1..n, 0, fn _, acc -> acc + roll(s, e?) end) end
  end

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
end
