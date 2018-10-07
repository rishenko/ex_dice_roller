defmodule ExDiceRoller.Compiler do
  @moduledoc """
  Provides functionality for compiling expressions into ready-to-execute
  functions.
  """

  alias ExDiceRoller.{Parser, Tokenizer}
  @type compiled_val :: compiled_fun | number
  @type compiled_fun :: (args, opts -> number)
  @type fun_info_tuple :: {function, atom, list(any)}
  @type args :: Keyword.t()
  @type opts :: list(atom | {atom, any})

  @doc """
  Compiles a provided `t:Parser.expression/0` into an anonymous function.

      iex> {:ok, roll_fun} = ExDiceRoller.compile("1dx+10")
      iex> ExDiceRoller.execute(roll_fun, x: 5)
      14
      iex> ExDiceRoller.execute(roll_fun, x: "10d100")
      72
  """
  @spec compile(Parser.expression()) :: compiled_val
  def compile({:digit, compiled_val}),
    do: compiled_val |> to_string() |> String.to_integer()

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

  def compile({:var, _} = var), do: compile_var(var)

  @doc """
  Shows the nested functions and relationships of a compiled function.

      > {:ok, fun} = ExDiceRoller.compile("1d8+(1-x)d(2*y)")
      #=> {:ok, #Function<0.84780260/1 in ExDiceRoller.Compiler.compile_add/4>}

      > ExDiceRoller.Compiler.fun_info fun
      #=> {#Function<0.16543174/1 in ExDiceRoller.Compiler.compile_add/4>,
      :"-compile_add/4-fun-0-",
      [
        {#Function<12.16543174/1 in ExDiceRoller.Compiler.compile_roll/4>,
          :"-compile_roll/4-fun-3-", [1, 8]},
        {#Function<9.16543174/1 in ExDiceRoller.Compiler.compile_roll/4>,
          :"-compile_roll/4-fun-0-",
          [
            {#Function<15.16543174/1 in ExDiceRoller.Compiler.compile_sub/4>,
            :"-compile_sub/4-fun-2-",
            [
              1,
              {#Function<16.16543174/1 in ExDiceRoller.Compiler.compile_var/1>,
                :"-compile_var/1-fun-0-", ['x']}
            ]},
            {#Function<8.16543174/1 in ExDiceRoller.Compiler.compile_mul/4>,
            :"-compile_mul/4-fun-2-",
            [
              2,
              {#Function<16.16543174/1 in ExDiceRoller.Compiler.compile_var/1>,
                :"-compile_var/1-fun-0-", ['y']}
            ]}
          ]}
      ]}

  """
  @spec fun_info(compiled_fun) :: fun_info_tuple
  def fun_info(fun) when is_function(fun) do
    info = :erlang.fun_info(fun)

    {fun, info[:name],
     info[:env]
     |> Enum.reverse()
     |> Enum.map(fn child ->
       fun_info(child)
     end)}
  end

  def fun_info(num) when is_number(num), do: num
  def fun_info(str) when is_list(str), do: str

  @spec compile_roll(compiled_val, boolean, compiled_val, boolean) :: compiled_fun
  defp compile_roll(num, true, sides, true) do
    fn args, opts -> roll_final(num.(args, opts), sides.(args, opts), opts) end
  end

  defp compile_roll(num, true, sides, false),
    do: fn args, opts -> roll_final(num.(args, opts), sides, opts) end

  defp compile_roll(num, false, sides, true),
    do: fn args, opts -> roll_final(num, sides.(args, opts), opts) end

  defp compile_roll(num, false, sides, false),
    do: fn _args, opts -> roll_final(num, sides, opts) end

  @spec roll_final(number, number, list(atom | tuple)) :: integer
  defp roll_final(0, _, _), do: 0
  defp roll_final(_, 0, _), do: 0

  defp roll_final(num, sides, opts) when num >= 0 and sides >= 0 do
    num = round(num)
    sides = round(sides)
    explode? = :explode in opts

    Enum.reduce(1..num, 0, fn _, total ->
      total + roll(sides, explode?)
    end)
  end

  defp roll_final(_, _, _),
    do: raise(ArgumentError, "neither number of dice nor number of sides cannot be less than 0")

  defp roll(sides, false) do
    Enum.random(1..sides)
  end

  defp roll(sides, true) do
    result = Enum.random(1..sides)
    explode_roll(sides, result, result)
  end

  defp explode_roll(sides, sides, acc) do
    result = Enum.random(1..sides)
    explode_roll(sides, result, acc + result)
  end

  defp explode_roll(_, _, acc), do: acc

  @spec compile_op(list, compiled_val, boolean, compiled_val, boolean) :: compiled_val
  defp compile_op('+', l, l_fun?, r, r_fun?), do: compile_add(l, l_fun?, r, r_fun?)
  defp compile_op('-', l, l_fun?, r, r_fun?), do: compile_sub(l, l_fun?, r, r_fun?)
  defp compile_op('*', l, l_fun?, r, r_fun?), do: compile_mul(l, l_fun?, r, r_fun?)
  defp compile_op('/', l, l_fun?, r, r_fun?), do: compile_div(l, l_fun?, r, r_fun?)

  @spec compile_add(compiled_val, boolean, compiled_val, boolean) :: compiled_val
  defp compile_add(l, true, r, true), do: fn args, opts -> l.(args, opts) + r.(args, opts) end
  defp compile_add(l, true, r, false), do: fn args, opts -> l.(args, opts) + r end
  defp compile_add(l, false, r, true), do: fn args, opts -> l + r.(args, opts) end
  defp compile_add(l, false, r, false), do: l + r

  @spec compile_sub(compiled_val, boolean, compiled_val, boolean) :: compiled_val
  defp compile_sub(l, true, r, true), do: fn args, opts -> l.(args, opts) - r.(args, opts) end
  defp compile_sub(l, true, r, false), do: fn args, opts -> l.(args, opts) - r end
  defp compile_sub(l, false, r, true), do: fn args, opts -> l - r.(args, opts) end
  defp compile_sub(l, false, r, false), do: l - r

  @spec compile_mul(compiled_val, boolean, compiled_val, boolean) :: compiled_val
  defp compile_mul(l, true, r, true), do: fn args, opts -> l.(args, opts) * r.(args, opts) end
  defp compile_mul(l, true, r, false), do: fn args, opts -> l.(args, opts) * r end
  defp compile_mul(l, false, r, true), do: fn args, opts -> l * r.(args, opts) end
  defp compile_mul(l, false, r, false), do: l * r

  @spec compile_div(compiled_val, boolean, compiled_val, boolean) :: compiled_val
  defp compile_div(l, true, r, true), do: fn args, opts -> l.(args, opts) / r.(args, opts) end
  defp compile_div(l, true, r, false), do: fn args, opts -> l.(args, opts) / r end
  defp compile_div(l, false, r, true), do: fn args, opts -> l / r.(args, opts) end
  defp compile_div(l, false, r, false), do: l / r

  @spec compile_var({:var, charlist}) :: compiled_fun
  defp compile_var({:var, var}), do: fn args, opts -> var_final(var, args, opts) end

  @spec var_final(charlist, Keyword.t(), list(atom | tuple)) :: number
  defp var_final(var, args, _opts) do
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
          true -> maybe_fun.([], [])
        end
    end
  end
end
