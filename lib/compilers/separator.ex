defmodule ExDiceRoller.Compilers.Separator do
  @moduledoc """
  Handles the `,` separator for rolls.

  The separator allows for multiple, separate dice expressions to be evaluated
  and only one returned based on provided options:

  * `:highest`: returns the highest calculated value and is the default option
  * `:lowest`: returns the lowest calculated value

  Examples:

      iex> ExDiceRoller.roll("1,2")
      2
      iex> ExDiceRoller.roll("1,1")
      1
      iex> ExDiceRoller.roll("1,2", opts: [:highest])
      2
      iex> ExDiceRoller.roll("1,2", opts: [:lowest])
      1
      iex> ExDiceRoller.roll("1d6+2,10d8+3", opts: [:highest])
      49
      iex> ExDiceRoller.roll("1d6+8,10d8+5", opts: [:lowest])
      14


  Seperator expressions can be wrapped in parentheses to be utilized it as a
  subexpression in a larger expression.

  Examples:

      iex> ExDiceRoller.roll("(5d1,2d1)+5", opts: [:highest])
      10
      iex> ExDiceRoller.roll("(5d1,2d1)+5", opts: [:lowest])
      7

  ## Separator Use And Keeping Dice

  The separator can be used alongside kept dice rolls, provided:

  * one side is a list and the other a number
  * both sides are lists of equal length

  When both sides are lists of equal length, separator will begin comparing the
  values from both lists by index location.


      iex> ExDiceRoller.roll("5d6,5d100", opts: [:keep, :lowest])
      [2, 2, 6, 4, 5]
      iex> ExDiceRoller.roll("5d6,5d100", opts: [:keep, :highest])
      [47, 6, 49, 91, 54]

      iex> ExDiceRoller.roll("(5d2,5d6)+5", opts: [:highest, :keep])
      [7, 9, 9, 11, 6]
      iex> ExDiceRoller.roll("(5d1,5d100)+5", opts: [:lowest, :keep])
      [6, 6, 6, 6, 6]

      iex> ExDiceRoller.roll("5d6, 3", opts: [:keep])
      [3, 3, 6, 4, 5]
      iex> ExDiceRoller.roll("3, 5d6", opts: [:keep])
      [3, 4, 4, 6, 3]

      iex> ExDiceRoller.roll("4, xd5", x: ["1d4", 2.5], opts: [:keep])
      [5, 4, 4, 4]

      iex> ExDiceRoller.roll("2d4, 1d8", opts: [:keep])
      ** (ArgumentError) cannot use separator on lists of differing lengths
  """

  @behaviour ExDiceRoller.Compiler
  alias ExDiceRoller.{Compiler, ListComprehension}

  @impl true
  def compile({:sep, left_expr, right_expr}) do
    compile_sep(Compiler.delegate(left_expr), Compiler.delegate(right_expr))
  end

  @spec compile_sep(Compiler.compiled_val(), Compiler.compiled_val()) :: Compiler.compiled_fun()
  defp compile_sep(l, r) when is_function(l) and is_function(r),
    do: fn args -> high_low(l.(args), r.(args), args) end

  defp compile_sep(l, r) when is_function(l),
    do: fn args -> high_low(l.(args), r, args) end

  defp compile_sep(l, r) when is_function(r),
    do: fn args -> high_low(l, r.(args), args) end

  defp compile_sep(l, r), do: fn args -> high_low(l, r, args) end

  @spec high_low(Compiler.calculated_val(), Compiler.calculated_val(), Compiler.args()) ::
          Compiler.calculated_val()
  defp high_low(l, l, _), do: l

  defp high_low(l, r, args) when is_list(args) do
    opts = Keyword.get(args, :opts, [])

    case Enum.find(opts, &(&1 in [:highest, :lowest])) do
      :highest -> ListComprehension.apply(l, r, :highest, "separator", &do_high_low/3)
      :lowest -> ListComprehension.apply(l, r, :lowest, "separator", &do_high_low/3)
      _ -> ListComprehension.apply(l, r, :highest, "separator", &do_high_low/3)
    end
  end

  @spec do_high_low(Compiler.calculated_val(), Compiler.calculated_val(), :highest | :lowest) ::
          Compiler.calculated_val()
  defp do_high_low(l, r, :highest) when l > r, do: l
  defp do_high_low(_, r, :highest), do: r
  defp do_high_low(l, r, :lowest) when l < r, do: l
  defp do_high_low(_, r, :lowest), do: r
end
