defmodule ExDiceRoller.Compiler do
  @moduledoc """
  Provides functionality for compiling expressions into ready-to-execute functions.
  """

  alias ExDiceRoller.{Parser, Tokenizer}

  @type intermediary_value :: compiled_function | number
  @type compiled_function :: (Keyword.t() -> number)

  @doc """
  Compiles a provided `t:Parser.expression/0` into an anonymous function.

  ```elixir
    iex> {:ok, roll_fun} = ExDiceRoller.compile("1dx+10")
    {:ok, #Function<8.36233920/1 in ExDiceRoller.Compiler.compile_op/5>}
    iex> ExDiceRoller.execute(roll_fun, x: 5)
    11
    iex> ExDiceRoller.execute(roll_fun, x: "10d100")
    523
  ```
  """
  @spec compile(Parser.expression()) :: intermediary_value
  def compile({:digit, intermediary_value}),
    do: intermediary_value |> to_string() |> String.to_integer()

  def compile({:roll, left_expr, right_expr}) do
    num = compile(left_expr)
    sides = compile(right_expr)

    compile_roll(num, is_function(num), sides, is_function(sides))
  end

  def compile({{:operator, op}, left_expr, right_expr}) do
    left_expr = compile(left_expr)
    right_expr = compile(right_expr)

    compile_op(op, left_expr, is_function(left_expr), right_expr, is_function(right_expr))
  end

  def compile({:var, var}) do
    fn args -> var_final(var, args) end
  end

  @doc """
  Shows the nested functions and relationships of a compiled function.

  ```elixir

    > {:ok, fun} = ExDiceRoller.compile("1d8+(1-x)d(2*y)")
    {:ok, #Function<7.36233920/1 in ExDiceRoller.Compiler.compile_op/5>}

    > ExDiceRoller.Compiler.fun_info(fun)
    {#Function<7.36233920/1 in ExDiceRoller.Compiler.compile_op/5>,
    [
      {#Function<13.36233920/1 in ExDiceRoller.Compiler.compile_roll/4>,
        [
          {#Function<6.36233920/1 in ExDiceRoller.Compiler.compile_op/5>,
          [{#Function<0.36233920/1 in ExDiceRoller.Compiler.compile/1>, ['y']}, 2]},
          {#Function<3.36233920/1 in ExDiceRoller.Compiler.compile_op/5>,
          [{#Function<0.36233920/1 in ExDiceRoller.Compiler.compile/1>, ['x']}, 1]}
        ]},
      {#Function<16.36233920/1 in ExDiceRoller.Compiler.compile_roll/4>, [8, 1]}
    ]}
  ```
  """
  @spec fun_info(compiled_function) :: Keyword.t
  def fun_info(fun) when is_function(fun) do
    info = :erlang.fun_info(fun)

    {fun,
     info
     |> Keyword.get(:env)
     |> Enum.map(fn child ->
       fun_info(child)
     end)}
  end

  def fun_info(num) when is_number(num), do: num
  def fun_info(str) when is_list(str), do: str

  @spec compile_roll(intermediary_value, boolean, intermediary_value, boolean) ::
          compiled_function
  defp compile_roll(num, true, sides, true),
    do: fn args -> roll_final(num.(args), sides.(args)) end

  defp compile_roll(num, true, sides, false), do: fn args -> roll_final(num.(args), sides) end
  defp compile_roll(num, false, sides, true), do: fn args -> roll_final(num, sides.(args)) end
  defp compile_roll(num, false, sides, false), do: fn _args -> roll_final(num, sides) end

  @spec roll_final(number, number) :: integer
  defp roll_final(0, _), do: 0

  defp roll_final(num, sides) when num >= 0 and sides >= 0 do
    num = round(num)
    sides = round(sides)
    Enum.reduce(1..num, 0, fn _, total -> Enum.random(1..sides) + total end)
  end

  defp roll_final(_, _),
    do: raise(ArgumentError, "neither number of dice nor number of sides cannot be less than 0")

  @spec compile_op(list, intermediary_value, boolean, intermediary_value, boolean) ::
          intermediary_value
  defp compile_op('+', l, true, r, true), do: fn args -> l.(args) + r.(args) end
  defp compile_op('-', l, true, r, true), do: fn args -> l.(args) - r.(args) end
  defp compile_op('*', l, true, r, true), do: fn args -> l.(args) * r.(args) end
  defp compile_op('/', l, true, r, true), do: fn args -> l.(args) / r.(args) end
  defp compile_op('+', l, true, r, false), do: fn args -> l.(args) + r end
  defp compile_op('-', l, true, r, false), do: fn args -> l.(args) - r end
  defp compile_op('*', l, true, r, false), do: fn args -> l.(args) * r end
  defp compile_op('/', l, true, r, false), do: fn args -> l.(args) / r end
  defp compile_op('+', l, false, r, true), do: fn args -> l + r.(args) end
  defp compile_op('-', l, false, r, true), do: fn args -> l - r.(args) end
  defp compile_op('*', l, false, r, true), do: fn args -> l * r.(args) end
  defp compile_op('/', l, false, r, true), do: fn args -> l / r.(args) end

  defp compile_op('+', l, false, r, false), do: l + r
  defp compile_op('-', l, false, r, false), do: l - r
  defp compile_op('*', l, false, r, false), do: l * r
  defp compile_op('/', l, false, r, false), do: l / r

  @spec var_final(charlist, Keyword.t()) :: number
  defp var_final(var, args) do
    key = var |> to_string() |> String.to_atom()

    case Keyword.get(args, key) do
      nil ->
        raise ArgumentError, "no variable #{inspect(var)} was found in the arguments"

      val when is_integer(val) or is_float(val) ->
        val

      val when is_bitstring(val) ->
        {:ok, tokens} = Tokenizer.tokenize(val)
        {:ok, parsed} = Parser.parse(tokens)
        maybe_fun = compile(parsed)

        case is_function(maybe_fun) do
          false -> maybe_fun
          true -> maybe_fun.([])
        end
    end
  end
end
