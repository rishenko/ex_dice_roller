defmodule ExDiceRoller.Sigil do
  @moduledoc """
  Handles the sigil `~a` for dice rolling. If no options are specified, the
  sigil will return the compiled function based on the provided roll. Note that
  variables cannot be present in the expression when invoking a roll directly
  from the sigil.

  Also note that if you wish to use the `/` operator with the sigil, you will
  need to use a different delimiter. Example: `~a|1d4+4d6/2d4|`.

  The sigil returns bare values, not `{:ok, _}` tuples. An invalid expression
  or option, or a failed roll, raises `ExDiceRoller.Error`.

  The following options are available, with each invoking a roll:

  * `r`: Compiles and invokes the roll. Variables are not supported with this.
  * `e`: Turns on the exploding dice mechanic.
  * `h`: Select the highest of the calculated values when using the `,`
  separator.
  * `l`: Select the lowest of the calculated values when using the `,`
  separator.
  * `k`: Keeps the value for each dice roll and returns it as a list.

  ## Examples

      iex> import ExDiceRoller.Sigil
      ExDiceRoller.Sigil
      iex> fun = ~a/1+1/
      iex> fun.([])
      2

      iex> import ExDiceRoller.Sigil
      iex> fun = ~a/1d4/
      iex> fun.([])
      1
      iex> fun.([])
      4

      iex> import ExDiceRoller.Sigil
      iex> ~a/1d6+1/r
      4
      iex> ~a/1d2/re
      7

  ## Compile-time parsing

  `~a` is a macro. When the expression is a literal (no `\#{}`
  interpolation), it is tokenized, parsed, and checked when your code
  compiles, so a malformed expression or an unknown flag is a compile error.
  The roll function is built the first time the sigil runs and kept in
  `:persistent_term`, so later calls skip parsing and compiling. An
  interpolated expression can't be checked early; it is parsed and compiled
  each time it runs, and errors are raised at run time.
  """

  alias ExDiceRoller.{Compiler, Error, Parser, Tokenizer}

  @doc false
  defmacro sigil_a(roll, opts)

  defmacro sigil_a({:<<>>, _meta, [roll_string]}, opts) when is_binary(roll_string),
    do: compile_time(roll_string, opts)

  defmacro sigil_a(roll_string, opts) when is_binary(roll_string),
    do: compile_time(roll_string, opts)

  defmacro sigil_a(roll, opts) do
    quote do: ExDiceRoller.Sigil.__runtime__(unquote(roll), unquote(opts))
  end

  # Parses and validates at compile time; the generated code fetches (or, on
  # first use, builds and stores) the compiled function by its parse tree.
  defp compile_time(roll_string, opts) do
    roll_opts = translate_opts!(opts)
    tree = parse!(roll_string)

    fun =
      quote do
        ExDiceRoller.Sigil.__fetch__(unquote(key(tree)), unquote(Macro.escape(tree)))
      end

    case roll_opts do
      nil -> fun
      [] -> quote do: ExDiceRoller.execute!(unquote(fun))
      _ -> quote do: ExDiceRoller.execute!(unquote(fun), opts: unquote(roll_opts))
    end
  end

  # The :persistent_term key for a parse tree, computed at compile time. Keying
  # on the tree itself would hash and compare the whole tree on every call; a
  # 59-bit digest stays a small integer, which is cheap to hash. The chance
  # that two different trees in one program share a key is about n^2 / 2^60
  # for n distinct sigil expressions.
  @doc false
  @spec key(Parser.expression()) :: {module, non_neg_integer}
  def key(tree) do
    <<digest::59, _::bits>> = :erlang.md5(:erlang.term_to_binary(tree))
    {__MODULE__, digest}
  end

  @doc false
  # Returns the compiled function for a parse tree, building it once and
  # storing it under `key`.
  @spec __fetch__({module, non_neg_integer}, Parser.expression()) :: Compiler.compiled_fun()
  def __fetch__(key, tree) do
    case :persistent_term.get(key, nil) do
      nil ->
        fun = Compiler.compile(tree)
        :persistent_term.put(key, fun)
        fun

      fun ->
        fun
    end
  end

  @doc false
  # The sigil with an interpolated expression: everything happens at run time.
  @spec __runtime__(String.t(), charlist) :: Compiler.compiled_fun() | Compiler.calculated_val()
  def __runtime__(roll_string, opts) do
    roll_opts = translate_opts!(opts)
    fun = Compiler.compile(parse!(roll_string))

    case roll_opts do
      nil -> fun
      [] -> ExDiceRoller.execute!(fun)
      _ -> ExDiceRoller.execute!(fun, opts: roll_opts)
    end
  end

  # `nil` when there are no flags (return the function); otherwise the roll
  # options, which may be empty (`r` alone)
  defp translate_opts!([]), do: nil

  defp translate_opts!(opts) do
    case translate_opts(:binary.list_to_bin(opts), []) do
      {:ok, translated} -> translated -- [:execute]
      {:error, rest} -> raise Error, reason: :invalid_option, details: rest
    end
  end

  # names the expression in the message, since a sigil has no other context
  @spec parse!(String.t()) :: Parser.expression()
  defp parse!(roll_string) do
    with {:ok, tokens} <- Tokenizer.tokenize(roll_string),
         {:ok, tree} <- Parser.parse(tokens) do
      tree
    else
      {:error, %Error{} = err} ->
        raise %{
          err
          | message: "invalid dice expression #{inspect(roll_string)}: #{Exception.message(err)}"
        }
    end
  end

  @spec translate_opts(binary, list(atom)) :: {:ok, list(atom)} | {:error, any}
  defp translate_opts(<<?r, t::binary>>, acc), do: translate_opts(t, [:execute | acc])
  defp translate_opts(<<?e, t::binary>>, acc), do: translate_opts(t, [:explode | acc])
  defp translate_opts(<<?h, t::binary>>, acc), do: translate_opts(t, [:highest | acc])
  defp translate_opts(<<?l, t::binary>>, acc), do: translate_opts(t, [:lowest | acc])
  defp translate_opts(<<?k, t::binary>>, acc), do: translate_opts(t, [:keep | acc])
  defp translate_opts(<<>>, acc), do: {:ok, acc}
  defp translate_opts(rest, _acc), do: {:error, rest}
end
