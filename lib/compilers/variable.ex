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
      iex> ExDiceRoller.roll("xdy+z", [x: 5, y: 10, z: 50])
      82
      iex> ExDiceRoller.roll("xdy+z", [x: 5, y: 10, z: ~a/15d100/])
      739
      iex> ExDiceRoller.roll("xdy+z", [x: [1, 2, 3], y: 1, z: 5], [:keep])
      [6, 6, 6, 6, 6, 6]
      iex> ExDiceRoller.roll("xdy+z", [x: 1, y: [1, 10, 100], z: -6], [:keep])
      [-5, 0, 68]
      iex> ExDiceRoller.roll("xdy+z", [x: [~a/1d2/, "1d4+1"], y: ["3,4d20/2", ~a/1d6/], z: 2], [:keep])
      [3, 4, 5, 5, 3, 7, 4, 5, 4, 3, 5, 4, 3, 4, 7, 3, 5, 4, 4, 5]

      iex> ExDiceRoller.roll("1+x")
      ** (ArgumentError) no variable 'x' was found in the arguments
  """

  @behaviour ExDiceRoller.Compiler
  alias ExDiceRoller.{Compiler, Tokenizer, Parser}

  @impl true
  def compile({:var, _} = var), do: compile_var(var)

  @spec compile_var({:var, charlist}) :: Compiler.compiled_fun()
  defp compile_var({:var, var}), do: fn args, opts -> var_final(var, args, opts) end

  @spec var_final(charlist, Compiler.args(), Compiler.opts()) :: number
  defp var_final(var, args, opts) do
    key = var |> to_string() |> String.to_atom()

    args
    |> Keyword.get(key)
    |> var_final_arg(var, opts)
  end

  @spec var_final_arg(any, charlist, Compiler.opts()) :: number
  defp var_final_arg(nil, var, _),
    do: raise(ArgumentError, "no variable #{inspect(var)} was found in the arguments")

  defp var_final_arg(val, _, _) when is_number(val), do: val
  defp var_final_arg(val, _, opts) when is_function(val), do: val.([], opts)

  defp var_final_arg(val, var, opts) when is_bitstring(val) do
    {:ok, tokens} = Tokenizer.tokenize(val)
    {:ok, parsed} = Parser.parse(tokens)
    compiled_arg = Compiler.delegate(parsed)
    var_final_arg(compiled_arg, var, opts)
  end

  defp var_final_arg(val, var, opts) when is_list(val) do
    Enum.map(val, &var_final_arg(&1, var, opts))
  end
end
