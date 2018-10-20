defmodule ExDiceRoller.ListComprehension do
  @moduledoc """
  Contains functionality for list comphrensions in ExDiceRoller.

  ExDiceRoller also has a certain amount of list comprehension support when
  calculating dice roll equations and 'keeping' rolls. The default behavior when
  working with kept rolls is as follows:

  1. If one side of an expression is a list, and the other a value, the action
  will apply the value to each value in the list.
  2. If both sides of an expression are lists of equal length, the values of
  each list are applied to their counterpart in the other list. An error is
  raised if the lengths of the two lists are different.
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

  Example with lists of differing lengths:

      iex> ExDiceRoller.roll("5d6+6d6", [], [:keep])
      ** (ArgumentError) cannot use math operators on lists of differing lengths

  Example of dice rolls of dice rolls:

      iex> ExDiceRoller.roll("1d1d4", [], [:keep])
      [1]
      iex> ExDiceRoller.roll("2d1d4", [], [:keep])
      [4, 2]
      iex> ExDiceRoller.roll("2d6d4", [], [:keep])
      [2, 4, 4, 2, 3, 2, 4, 4, 4]
  """

  alias ExDiceRoller.Compiler

  @type left :: Compiler.compiled_val() | list(Compiler.compiled_val())
  @type right :: Compiler.compiled_val() | list(Compiler.compiled_val())
  @type return_val :: Compiler.compiled_val() | list(Compiler.compiled_val())
  @type opts :: any | list(any)

  @doc """
  Applies the given function and options to both the left and right sides of
  an expression. If either or both sides are lists, the functions are applied
  against each element of the list. Any resulting lists or nested lists, will
  be flattened to a single list.
  """
  @spec flattened_apply(left, right, opts, function) :: return_val

  def flattened_apply(l, r, opts, fun) when is_list(l) do
    Enum.flat_map(l, &flattened_apply(&1, r, opts, fun))
  end

  def flattened_apply(l, r, opts, fun) when is_list(r) do
    Enum.flat_map(r, &flattened_apply(l, &1, opts, fun))
  end

  def flattened_apply(l, r, opts, fun), do: fun.(l, r, opts)

  @doc """
  Applies the given function and options to both the left and right sides of
  an expression.

  If both sides are lists, a check is made to verify they are the same size. If
  they are not the same size, an error is raised. Otherwise, the values of
  each list are applied to their counterpart in the other list.
  """
  @spec apply(left, right, opts, String.t(), function) :: return_val

  def apply(l, r, _, err_name, _) when is_list(l) and is_list(r) and length(l) != length(r) do
    raise ArgumentError, "cannot use #{err_name} on lists of differing lengths"
  end

  def apply(l, r, opts, _, fun) when is_list(l) and is_list(r) do
    Enum.map(0..(length(l) - 1), &fun.(Enum.at(l, &1), Enum.at(r, &1), opts))
  end

  def apply(l, r, opts, err_name, fun) when is_list(l) and not is_list(r) do
    Enum.map(l, &apply(&1, r, opts, err_name, fun))
  end

  def apply(l, r, opts, err_name, fun) when not is_list(l) and is_list(r) do
    Enum.map(r, &apply(l, &1, opts, err_name, fun))
  end

  def apply(l, r, opts, _, fun), do: fun.(l, r, opts)
end
