defmodule ExDiceRoller.Compilers.Math do
  @moduledoc """
  Handles compiling expressions using common mathematical operators.

      iex> {:ok, tokens} = ExDiceRoller.Tokenizer.tokenize("1+x")
      {:ok, [{:digit, 1, '1'}, {:basic_operator, 1, '+'}, {:var, 1, 'x'}]}
      iex> {:ok, parse_tree} = ExDiceRoller.Parser.parse(tokens)
      {:ok, {{:operator, '+'}, {:digit, '1'}, {:var, 'x'}}}
      iex> fun = ExDiceRoller.Compilers.Math.compile(parse_tree)
      iex> fun.([x: 2], [])
      3

  ExDiceRoller uses [infix notation](https://en.wikipedia.org/wiki/Infix_notation)
  when working with mathematical operators. Below is the list of operators
  currently supported by ExDiceRoller:

  * `+`: adds the values on both sides of the expression
  * `-`: subtracts the value on the right from the value on the left
  * `*`: multiplies the values on both sides of the expression
  * `/`: divides, with the left value as the dividend, the right the divisor
  * `%`: [modulo](https://en.wikipedia.org/wiki/Modulo_operation), with the
  left the dividend, the right the divisor
  * `^`: exponentiation, with the left the base, the right the exponent
  """

  @behaviour ExDiceRoller.Compiler
  alias ExDiceRoller.Compiler

  @operators [
    {'+', &Kernel.+/2, "add"},
    {'-', &Kernel.-/2, "sub"},
    {'*', &Kernel.*/2, "mul"},
    {'/', &Kernel.//2, "div"},
    {'%', &__MODULE__.modulo/2, "mod"},
    {'^', &:math.pow/2, "exp"}
  ]

  @impl true
  def compile({{:operator, op}, left_expr, right_expr}) do
    compile_op(op, Compiler.delegate(left_expr), Compiler.delegate(right_expr))
  end

  @doc "Function used for modulo calculations."
  @spec modulo(number, number) :: integer
  def modulo(l, r), do: rem(Compiler.round_val(l), Compiler.round_val(r))

  @spec compile_op(charlist, Compiler.compiled_val(), Compiler.compiled_val()) ::
          Compiler.compiled_val()

  for {char, _, name} <- @operators do
    defp compile_op(unquote(char), l, r), do: unquote(:"compile_#{name}")(l, r)
  end

  for {_, fun, name} <- @operators do
    @spec unquote(:"compile_#{name}")(Compiler.compiled_val(), Compiler.compiled_val()) ::
            Compiler.compiled_val()

    defp unquote(:"compile_#{name}")(l, r) when is_function(l) and is_function(r) do
      fn args, opts -> op(l.(args, opts), r.(args, opts), unquote(fun)) end
    end

    defp unquote(:"compile_#{name}")(l, r) when is_function(l) do
      fn args, opts -> op(l.(args, opts), r, unquote(fun)) end
    end

    defp unquote(:"compile_#{name}")(l, r) when is_function(r) do
      fn args, opts -> op(l, r.(args, opts), unquote(fun)) end
    end

    defp unquote(:"compile_#{name}")(l, r), do: op(l, r, unquote(fun))
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
