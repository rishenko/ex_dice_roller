defmodule ExDiceRoller.Filters do
  @moduledoc "Manages functionality around filtering results."

  alias ExDiceRoller.Compiler

  @doc """
  Filters the final value using either a provided comparator and comparison number,
  such as `>=: 3`, or dropping highest or lowest value, such as `drop_highest:
  true`. Possible comparators include:

  * numerical: `>=`, `<=`, `=`, `!=`, <`, and `>` in the format `<comparator>:
    <number>`.
  * boolean: `drop_highest`, `drop_lowest`, `drop_highest_lowest` in the format
    `<comparator>: true | false`.

  Note that boolean filters require a list of values, such as adding the
  separator (`,`) comparator or using the `:keep` option.

  Examples:

      iex> ExDiceRoller.roll("1d4", >=: 5)
      []

      iex> ExDiceRoller.roll("6d6", <=: 4, opts: :keep)
      [3, 2, 4, 2]

      iex> ExDiceRoller.roll("4d10", drop_highest: true, opts: :keep)
      [9, 6, 4]

      iex> ExDiceRoller.roll("4d10", drop_highest_lowest: true, opts: :keep)
      [6, 9]

  """
  @spec filter(Compiler.calculated_val(), list(tuple)) :: Compiler.calculated_val()
  def filter(val, []), do: val
  def filter(val, filters) when is_number(val), do: filter([val], filters)

  def filter(val, filters) when length(filters) > 0 do
    Enum.reduce(filters, val, &do_filter(&2, &1))
  end

  @doc """
  Extract all filters from an argument list and return them as well as the
  updated argument list.
  """
  @spec get_filters(Keyword.t()) :: {list(any), Keyword.t()}
  def get_filters(args) do
    filters = do_get_filter(args, [])

    {filters,
     Enum.filter(args, fn {k, _} ->
       k not in [:>=, :!=, :<=, :=, :>, :<, :drop_lowest, :drop_highest, :drop_highest_lowest]
     end)}
  end

  @spec do_filter(list(Compiler.calculated_val()), tuple) :: list(Compiler.calculated_val())
  defp do_filter(val, {:>=, num}), do: Enum.filter(val, &(&1 >= num))
  defp do_filter(val, {:<=, num}), do: Enum.filter(val, &(&1 <= num))
  defp do_filter(val, {:=, num}), do: Enum.filter(val, &(&1 == num))
  defp do_filter(val, {:!=, num}), do: Enum.filter(val, &(&1 != num))
  defp do_filter(val, {:>, num}), do: Enum.filter(val, &(&1 > num))
  defp do_filter(val, {:<, num}), do: Enum.filter(val, &(&1 < num))
  defp do_filter(val, {:drop_lowest, true}), do: val |> Enum.sort() |> Enum.drop(1)

  defp do_filter(val, {:drop_highest, true}),
    do: val |> Enum.sort() |> Enum.reverse() |> Enum.drop(1)

  defp do_filter(val, {:drop_highest_lowest, true}) do
    val |> Enum.sort() |> Enum.drop(1) |> Enum.drop(-1)
  end

  @spec do_get_filter(Keyword.t(), list(any)) :: list(any)
  defp do_get_filter([], acc), do: acc
  defp do_get_filter([{:>=, _} = f | rest], acc), do: do_get_filter(rest, [f] ++ acc)
  defp do_get_filter([{:<=, _} = f | rest], acc), do: do_get_filter(rest, [f] ++ acc)
  defp do_get_filter([{:=, _} = f | rest], acc), do: do_get_filter(rest, [f] ++ acc)
  defp do_get_filter([{:!=, _} = f | rest], acc), do: do_get_filter(rest, [f] ++ acc)
  defp do_get_filter([{:>, _} = f | rest], acc), do: do_get_filter(rest, [f] ++ acc)
  defp do_get_filter([{:<, _} = f | rest], acc), do: do_get_filter(rest, [f] ++ acc)
  defp do_get_filter([{:drop_lowest, true} = f | rest], acc), do: do_get_filter(rest, [f] ++ acc)
  defp do_get_filter([{:drop_highest, true} = f | rest], acc), do: do_get_filter(rest, [f] ++ acc)

  defp do_get_filter([{:drop_highest_lowest, true} = f | rest], acc),
    do: do_get_filter(rest, [f] ++ acc)

  defp do_get_filter([_ | rest], acc), do: do_get_filter(rest, acc)
end
