defmodule ExDiceRoller.Compiler do
  @moduledoc """
  Provides functionality for compiling expressions into ready-to-execute
  functions.

      > parsed =
        {{:operator, '+'},
        {{:operator, '-'}, {:roll, {:digit, '1'}, {:digit, '4'}},
          {{:operator, '/'}, {:roll, {:digit, '3'}, {:digit, '6'}}, {:digit, '2'}}},
        {:roll, {:roll, {:digit, '1'}, {:digit, '4'}},
          {:roll, {:digit, '1'}, {:digit, '6'}}}}

      > fun = ExDiceRoller.Compiler.compile(parsed)
      #Function<0.47893785/2 in ExDiceRoller.Compiler.compile_add/4>

      > fun.([], [])
      4

      > ExDiceRoller.Compiler.fun_info(fun)
      {#Function<0.47893785/2 in ExDiceRoller.Compiler.compile_add/4>,
        :"-compile_add/4-fun-0-",
        [
          {#Function<13.47893785/2 in ExDiceRoller.Compiler.compile_sub/4>,
            :"-compile_sub/4-fun-0-",
            [
              {#Function<12.47893785/2 in ExDiceRoller.Compiler.compile_roll/4>,
              :"-compile_roll/4-fun-3-", [1, 4]},
              {#Function<4.47893785/2 in ExDiceRoller.Compiler.compile_div/4>,
              :"-compile_div/4-fun-1-",
              [
                {#Function<12.47893785/2 in ExDiceRoller.Compiler.compile_roll/4>,
                  :"-compile_roll/4-fun-3-", [3, 6]},
                2
              ]}
            ]},
          {#Function<9.47893785/2 in ExDiceRoller.Compiler.compile_roll/4>,
            :"-compile_roll/4-fun-0-",
            [
              {#Function<12.47893785/2 in ExDiceRoller.Compiler.compile_roll/4>,
              :"-compile_roll/4-fun-3-", [1, 4]},
              {#Function<12.47893785/2 in ExDiceRoller.Compiler.compile_roll/4>,
              :"-compile_roll/4-fun-3-", [1, 6]}
            ]}
        ]}

  """

  alias ExDiceRoller.{Parser, Tokenizer}
  @type compiled_val :: compiled_fun | number
  @type compiled_fun :: (args, opts -> integer)
  @type fun_info_tuple :: {function, atom, list(any)}
  @type args :: Keyword.t()
  @type opts :: list(atom | {atom, any})

  @doc """
  Compiles a provided `t:Parser.expression/0` into an anonymous function.

      iex> expr = "1d2+x"
      "1d2+x"
      iex> {:ok, tokens} = ExDiceRoller.Tokenizer.tokenize(expr)
      {:ok,
      [
        {:digit, 1, '1'},
        {:roll, 1, 'd'},
        {:digit, 1, '2'},
        {:basic_operator, 1, '+'},
        {:var, 1, 'x'}
      ]}
      iex> {:ok, parsed} = ExDiceRoller.Parser.parse(tokens)
      {:ok, {{:operator, '+'}, {:roll, {:digit, '1'}, {:digit, '2'}}, {:var, 'x'}}}
      iex> fun = ExDiceRoller.Compiler.compile(parsed)
      iex> fun.([x: 1], [:explode])
      2

  During calculation, float values are left as float for as long as possible.
  If a compiled roll is invoked with a float as the number of dice or sides,
  that value will be rounded to an integer. Finally, the return value is an
  integer. Rounding rules can be found at `Kernel.round/1`.
  """
  @spec compile(Parser.expression()) :: compiled_val
  def compile(expression) do
    compiled = do_compile(expression)

    compiled =
      case is_function(compiled) do
        false -> fn _args, _opts -> compiled end
        true -> compiled
      end

    fn args, opts ->
      args
      |> compiled.(opts)
      |> round()
    end
  end

  defp do_compile({:digit, compiled_val}),
    do: compiled_val |> to_string() |> String.to_integer()

  defp do_compile({:roll, left_expr, right_expr}) do
    num = do_compile(left_expr)
    sides = do_compile(right_expr)
    compile_roll(num, is_function(num), sides, is_function(sides))
  end

  defp do_compile({{:operator, op}, left_expr, right_expr}) do
    left_expr = do_compile(left_expr)
    right_expr = do_compile(right_expr)

    compile_op(op, left_expr, is_function(left_expr), right_expr, is_function(right_expr))
  end

  defp do_compile({:var, _} = var), do: compile_var(var)

  @doc """
  Shows the nested functions and relationships of a compiled function. The
  structure of the fun_info result is `{<function>, <atom with name, arity, and
  ordered function #>, [<recursive info about child functions>]}`.

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
  def fun_info(fun) do
    info = :erlang.fun_info(fun)
    do_fun_info(hd(info[:env]))
  end

  @spec do_fun_info(function | number | charlist) :: function | number | charlist
  defp do_fun_info(fun) when is_function(fun) do
    info = :erlang.fun_info(fun)

    {fun, info[:name],
     info[:env]
     |> Enum.reverse()
     |> Enum.map(fn child ->
       do_fun_info(child)
     end)}
  end

  defp do_fun_info(num) when is_number(num), do: num
  defp do_fun_info(str) when is_list(str), do: str

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
  defp compile_op('%', l, l_fun?, r, r_fun?), do: compile_mod(l, l_fun?, r, r_fun?)
  defp compile_op('^', l, l_fun?, r, r_fun?), do: compile_exp(l, l_fun?, r, r_fun?)

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

  @spec compile_mod(compiled_val, boolean, compiled_val, boolean) :: compiled_val
  defp compile_mod(l, true, r, true), do: fn args, opts -> rem(l.(args, opts), r.(args, opts)) end
  defp compile_mod(l, true, r, false), do: fn args, opts -> rem(l.(args, opts), r) end
  defp compile_mod(l, false, r, true), do: fn args, opts -> rem(l, r.(args, opts)) end
  defp compile_mod(l, false, r, false), do: rem(l, r)

  @spec compile_exp(compiled_val, boolean, compiled_val, boolean) :: compiled_val
  defp compile_exp(l, true, r, true), do: fn args, opts -> :math.pow(l.(args, opts), r.(args, opts)) end
  defp compile_exp(l, true, r, false), do: fn args, opts -> :math.pow(l.(args, opts), r) end
  defp compile_exp(l, false, r, true), do: fn args, opts -> :math.pow(l, r.(args, opts)) end
  defp compile_exp(l, false, r, false), do: :math.pow(l, r)

  @spec compile_var({:var, charlist}) :: compiled_fun
  defp compile_var({:var, var}), do: fn args, opts -> var_final(var, args, opts) end

  @spec var_final(charlist, args, opts) :: number
  defp var_final(var, args, opts) do
    key = var |> to_string() |> String.to_atom()

    args
    |> Keyword.get(key)
    |> var_final_arg(var, opts)
  end

  @spec var_final_arg(any, charlist, opts) :: number
  defp var_final_arg(nil, var, _),
    do: raise(ArgumentError, "no variable #{inspect(var)} was found in the arguments")

  defp var_final_arg(val, _, _) when is_integer(val), do: val
  defp var_final_arg(val, _, opts) when is_function(val), do: val.([], opts)

  defp var_final_arg(val, var, opts) when is_bitstring(val) do
    {:ok, tokens} = Tokenizer.tokenize(val)
    {:ok, parsed} = Parser.parse(tokens)
    compiled_arg = compile(parsed)

    var_final_arg(compiled_arg, var, opts)
  end
end
