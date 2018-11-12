defmodule ExDiceRoller.Compilers.Variable do
  @moduledoc """
  Handles compiling expressions that use variables.

  Variables can be used to replace single letter characters in an expression
  with a value, such as a number or an anonymous function that accepts list
  arguments (`args` and `opts`, respectively).

  Acceptable variable values include:

  * integers
  * floats
  * compiled functions matching `t:Compiler.compiled_fun/2`
  * strings that can be parsed by ExDiceRoller
  * lists composed of any of the above
  * lists of lists

  Note that an error will be raised if values are not supplied for all varaibles
  in an expression.

  ### Examples

      iex> import ExDiceRoller.Sigil
      ExDiceRoller.Sigil
      iex> ExDiceRoller.roll(~a/1+x/, [x: 5])
      6
      iex> ExDiceRoller.roll("xdy+z", x: 5, y: 10, z: 50)
      82
      iex> ExDiceRoller.roll("xdy+z", [x: 5, y: 10, z: ~a/15d100/])
      739
      iex> ExDiceRoller.roll("xdy+z", x: [1, 2, 3], y: 1, z: 5, opts: [:keep])
      [6, 6, 6, 6, 6, 6]
      iex> ExDiceRoller.roll("xdy+z", [x: 1, y: [1, 10, 100], z: -6, opts: [:keep]])
      [-5, -4, 66]
      iex> ExDiceRoller.roll("xdy+z", x: [~a/1d2/, "1d4+1"], y: ["3,4d20/2", ~a/1d6/], z: 2, opts: [:keep])
      [8, 8, 3, 3, 3, 10, 4, 7, 6, 3, 5, 4, 4, 4, 3]

      iex> ExDiceRoller.roll("1+x")
      ** (ArgumentError) no variable 'x' was found in the arguments
  """

  @behaviour ExDiceRoller.Compiler
  alias ExDiceRoller.{Args, Compiler, Tokenizer, Parser}

  @impl true
  def compile({:var, _} = var), do: compile_var(var)

  @spec compile_var({:var, charlist}) :: Compiler.compiled_fun()
  defp compile_var({:var, var}), do: fn args -> var_final(var, args) end

  @spec var_final(charlist, Keyword.t()) :: number
  defp var_final(var, args) do
    key = var |> to_string() |> String.to_atom()

    args
    |> Args.get_var(key)
    |> var_final_arg(var, args)
  end

  @spec var_final_arg(any, charlist, Keyword.t()) :: number
  defp var_final_arg(nil, var, _),
    do: raise(ArgumentError, "no variable #{inspect(var)} was found in the arguments")

  defp var_final_arg(val, _, _) when is_number(val), do: val
  defp var_final_arg(val, _, args) when is_function(val), do: val.(args)

  defp var_final_arg(val, var, args) when is_bitstring(val) do
    {:ok, tokens} = Tokenizer.tokenize(val)
    {:ok, parsed} = Parser.parse(tokens)
    compiled_arg = Compiler.delegate(parsed)
    var_final_arg(compiled_arg, var, args)
  end

  defp var_final_arg(val, var, args) when is_list(val) do
    Enum.map(val, &var_final_arg(&1, var, args))
  end
end
