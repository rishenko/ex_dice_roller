defmodule ExDiceRoller.Compilers.Separator do
  @moduledoc """
  Handles the `,` separator for rolls.

  The separator allows for multiple, separate dice expressions to be evaluated
  and only one returned based on provided options:

  * `:highest`: returns the highest calculated value and is the default option
  * `:lowest`: returns the lowest calculated value

  Examples:

      iex> ExDiceRoller.roll("1,2", [], [])
      2
      iex> ExDiceRoller.roll("1,1", [], [])
      1
      iex> ExDiceRoller.roll("1,2", [], [])
      2
      iex> ExDiceRoller.roll("1,2", [], [:highest])
      2
      iex> ExDiceRoller.roll("1,2", [], [:lowest])
      1
      iex> ExDiceRoller.roll("1d6,10d8", [], [:highest])
      46
      iex> ExDiceRoller.roll("1d6,10d8", [], [:lowest])
      6

  ## Separator Use And Keeping Dice

  The separator can be used alongside kept dice rolls, provided both sides of
  the expression are lists of equal length. Otherwise, it obeys the same rules
  of kept roll list comprehension, where each die roll is compared to its
  counterpart.


      iex> ExDiceRoller.roll("5d6,5d100", [], [:keep, :lowest])
      [2, 2, 6, 4, 5]
      iex> ExDiceRoller.roll("5d6,5d100", [], [:keep, :highest])
      [47, 6, 49, 91, 54]
  """

  @behaviour ExDiceRoller.Compiler
  alias ExDiceRoller.Compiler

  @error_both_sides "separator can only be used when both sides are a list or both sides are a number"

  @impl true
  def compile({:sep, left_expr, right_expr}) do
    compile_sep(Compiler.delegate(left_expr), Compiler.delegate(right_expr))
  end

  @spec compile_sep(Compiler.compiled_val(), Compiler.compiled_val()) :: Compiler.compiled_val()
  defp compile_sep(l, r) when is_function(l) and is_function(r),
    do: fn args, opts -> high_low(l.(args, opts), r.(args, opts), opts) end

  defp compile_sep(l, r) when is_function(l),
    do: fn args, opts -> high_low(l.(args, opts), r, opts) end

  defp compile_sep(l, r) when is_function(r),
    do: fn args, opts -> high_low(l, r.(args, opts), opts) end

  defp compile_sep(l, r), do: fn _args, opts -> high_low(l, r, opts) end

  @spec high_low(Compiler.calculated_val(), Compiler.calculated_val(), :highest | :lowest) ::
          Compiler.calculated_val()
  defp high_low(l, l, _), do: l

  defp high_low(l, r, opts) when is_list(opts) do
    case Enum.find(opts, &(&1 in [:highest, :lowest])) do
      :highest -> high_low(l, r, :highest)
      :lowest -> high_low(l, r, :lowest)
      _ -> high_low(l, r, :highest)
    end
  end

  defp high_low(l, r, level) when is_list(l) and is_list(r) do
    if length(l) != length(r) do
      raise ArgumentError, "cannot use separator on lists of differing lengths"
    end

    Enum.map(0..(length(l) - 1), &high_low(Enum.at(l, &1), Enum.at(r, &1), level))
  end

  defp high_low(l, _, _) when is_list(l), do: raise(ArgumentError, @error_both_sides)
  defp high_low(_, r, _) when is_list(r), do: raise(ArgumentError, @error_both_sides)
  defp high_low(l, r, :highest) when l > r, do: l
  defp high_low(_, r, :highest), do: r
  defp high_low(l, r, :lowest) when l < r, do: l
  defp high_low(_, r, :lowest), do: r
end
