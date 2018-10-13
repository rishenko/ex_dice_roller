defmodule ExDiceRoller.Compilers.Math do
  @moduledoc """
  Handles compiling mathematical expressions.
  """

  @behaviour ExDiceRoller.Compiler
  alias ExDiceRoller.Compiler

  @impl true
  def compile({{:operator, op}, left_expr, right_expr}) do
    left_expr = Compiler.delegate(left_expr)
    right_expr = Compiler.delegate(right_expr)
    compile_op(op, left_expr, is_function(left_expr), right_expr, is_function(right_expr))
  end

  @operators [
    {'+', &Kernel.+/2, "add"},
    {'-', &Kernel.-/2, "sub"},
    {'*', &Kernel.*/2, "mul"},
    {'/', &Kernel.//2, "div"},
    {'%', &Kernel.rem/2, "mod"},
    {'^', &:math.pow/2, "exp"}
  ]

  for {char, fun, name} <- @operators do
    defp unquote(:"compile_#{name}")(l, true, r, true),
      do: fn args, opts -> op(l.(args, opts), r.(args, opts), unquote(fun)) end

    defp unquote(:"compile_#{name}")(l, true, r, false),
      do: fn args, opts -> op(l.(args, opts), r, unquote(fun)) end

    defp unquote(:"compile_#{name}")(l, false, r, true),
      do: fn args, opts -> op(l, r.(args, opts), unquote(fun)) end

    defp unquote(:"compile_#{name}")(l, false, r, false), do: op(l, r, unquote(fun))

    defp compile_op(unquote(char), l, l_fun?, r, r_fun?),
      do: unquote(:"compile_#{name}")(l, l_fun?, r, r_fun?)
  end

  @spec op(list | number, list | number, function) :: list | number
  defp op(l, r, fun) when is_list(l) and is_list(r) do
    if length(l) != length(r) do
      raise ArgumentError, "you cannot add two lists of different sizes"
    end

    Enum.map(0..(length(l) - 1), &fun.(Enum.at(l, &1), Enum.at(r, &1)))
  end

  defp op(l, r, fun) when is_list(l), do: Enum.map(l, &fun.(&1, r))
  defp op(l, r, fun) when is_list(r), do: Enum.map(r, &fun.(&1, l))
  defp op(l, r, fun), do: fun.(l, r)
end
