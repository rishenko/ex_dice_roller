defmodule ExDiceRoller.Tokenizer do
  @moduledoc """
  Provides functionality around tokenizing dice roll strings.

      iex> ExDiceRoller.Tokenizer.tokenize("1d4+6-(2dy)d(5*2d7-x)/3d8")
      {:ok,
      [
        {:int, 1, ~c"1"},
        {:roll, 1, ~c"d"},
        {:int, 1, ~c"4"},
        {:basic_operator, 1, ~c"+"},
        {:int, 1, ~c"6"},
        {:basic_operator, 1, ~c"-"},
        {:"(", 1, ~c"("},
        {:int, 1, ~c"2"},
        {:roll, 1, ~c"d"},
        {:var, 1, ~c"y"},
        {:")", 1, ~c")"},
        {:roll, 1, ~c"d"},
        {:"(", 1, ~c"("},
        {:int, 1, ~c"5"},
        {:complex_operator, 1, ~c"*"},
        {:int, 1, ~c"2"},
        {:roll, 1, ~c"d"},
        {:int, 1, ~c"7"},
        {:basic_operator, 1, ~c"-"},
        {:var, 1, ~c"x"},
        {:")", 1, ~c")"},
        {:complex_operator, 1, ~c"/"},
        {:int, 1, ~c"3"},
        {:roll, 1, ~c"d"},
        {:int, 1, ~c"8"}
      ]}
  """

  @type tokens :: [token, ...]
  @type token :: {token_type, integer, list}
  @type token_type ::
          :int
          | :float
          | :var
          | :basic_operator
          | :complex_operator
          | :exp_operator
          | :roll
          | :modifier
          | :","
          | :"("
          | :")"

  @typedoc """
  A dice modifier, written directly after a roll's sides. See
  `ExDiceRoller.Compilers.Roll` for the syntax.
  """
  @type modifier ::
          {:keep | :drop, :highest | :lowest, non_neg_integer}
          | {:reroll, :always | :once, comparator, integer}
          | :explode
  @type comparator :: :== | :< | :> | :<= | :>=

  @doc """
  Converts a roll-based string into tokens using leex. The input definition
  file is located at `src/dice_lexer.xrl`. See `t:token_type/0`, `t:token/0`,
  and `t:tokens/0` for the possible return values.

      iex> ExDiceRoller.Tokenizer.tokenize("2d8+3")
      {:ok,
      [
        {:int, 1, ~c"2"},
        {:roll, 1, ~c"d"},
        {:int, 1, ~c"8"},
        {:basic_operator, 1, ~c"+"},
        {:int, 1, ~c"3"}
      ]}
  """
  @spec tokenize(String.t()) :: {:ok, tokens} | {:error, ExDiceRoller.Error.t()}
  def tokenize(roll_string) do
    with charlist <- String.to_charlist(roll_string),
         {:ok, tokens, _} <- :dice_lexer.string(charlist),
         {:ok, tokens} <- scan(tokens, []) do
      {:ok, tokens}
    else
      {:error, {_line, :dice_lexer, reason}, _end_line} -> tokenizing_failed(reason)
      {:error, {:illegal, _} = reason} -> tokenizing_failed(reason)
    end
  end

  defp tokenizing_failed(reason),
    do: {:error, ExDiceRoller.Error.exception(reason: :tokenizing_failed, details: reason)}

  # The lexer reads every letter other than d/D as a variable. This pass turns
  # the letters that directly follow a roll's sides (`4d6kh3`, `1d20r1`) into
  # `:modifier` tokens; everywhere else they stay variables.
  @spec scan([tuple], [tuple]) :: {:ok, tokens} | {:error, {:illegal, charlist}}
  defp scan([], acc), do: {:ok, Enum.reverse(acc)}

  defp scan([{:roll, _, _} = roll | rest], acc) do
    case take_sides(rest) do
      {:ok, sides, rest} -> modifiers(rest, Enum.reverse(sides, [roll | acc]))
      :none -> scan(rest, [roll | acc])
      {:error, _} = err -> err
    end
  end

  defp scan([{type, _, chars} | _], _) when type in [:explode, :comparator],
    do: {:error, {:illegal, chars}}

  defp scan([token | rest], acc), do: scan(rest, [token | acc])

  defp modifiers(tokens, acc) do
    case take_modifier(tokens) do
      {:ok, modifier, rest} -> modifiers(rest, [modifier | acc])
      :none -> scan(tokens, acc)
    end
  end

  # the sides of a roll: a number, a variable, a signed number, or a
  # parenthesized group (scanned in turn, since it may hold rolls)
  defp take_sides([{type, _, _} = t | rest]) when type in [:int, :float, :var],
    do: {:ok, [t], rest}

  defp take_sides([{:basic_operator, _, _} = op, {type, _, _} = t | rest])
       when type in [:int, :float],
       do: {:ok, [op, t], rest}

  defp take_sides([{:"(", _, _} = open | rest]) do
    with {:ok, inner, close, rest} <- split_group(rest, 0, []),
         {:ok, inner} <- scan(inner, []) do
      {:ok, [open | inner] ++ [close], rest}
    else
      :unbalanced -> :none
      {:error, _} = err -> err
    end
  end

  defp take_sides(_), do: :none

  defp split_group([], _, _), do: :unbalanced

  defp split_group([{:")", _, _} = close | rest], 0, acc),
    do: {:ok, Enum.reverse(acc), close, rest}

  defp split_group([{:")", _, _} = t | rest], d, acc), do: split_group(rest, d - 1, [t | acc])
  defp split_group([{:"(", _, _} = t | rest], d, acc), do: split_group(rest, d + 1, [t | acc])
  defp split_group([t | rest], d, acc), do: split_group(rest, d, [t | acc])

  defguardp is_letter(t, lower) when elem(t, 2) == [lower] or elem(t, 2) == [lower - 32]
  defguardp is_var(t, lower) when elem(t, 0) == :var and is_letter(t, lower)

  defp take_modifier([{:explode, line, _} | rest]), do: {:ok, {:modifier, line, :explode}, rest}

  defp take_modifier([{:var, line, _} = k, h | rest]) when is_var(k, ?k) and is_var(h, ?h),
    do: keep_drop(:keep, :highest, line, rest)

  defp take_modifier([{:var, line, _} = k, l | rest]) when is_var(k, ?k) and is_var(l, ?l),
    do: keep_drop(:keep, :lowest, line, rest)

  defp take_modifier([{:var, line, _} = k | rest]) when is_var(k, ?k),
    do: keep_drop(:keep, :highest, line, rest)

  defp take_modifier([{:roll, line, _}, {:var, _, _} = h | rest]) when is_letter(h, ?h),
    do: keep_drop(:drop, :highest, line, rest)

  defp take_modifier([{:roll, line, _}, {:var, _, _} = l | rest]) when is_letter(l, ?l),
    do: keep_drop(:drop, :lowest, line, rest)

  defp take_modifier([{:var, line, _} = r, o | rest]) when is_var(r, ?r) and is_var(o, ?o),
    do: reroll(:once, line, rest)

  defp take_modifier([{:var, line, _} = r | rest]) when is_var(r, ?r),
    do: reroll(:always, line, rest)

  defp take_modifier(_), do: :none

  # the count is optional and defaults to 1
  defp keep_drop(kind, which, line, [{:int, _, n} | rest]),
    do: {:ok, {:modifier, line, {kind, which, List.to_integer(n)}}, rest}

  defp keep_drop(kind, which, line, rest), do: {:ok, {:modifier, line, {kind, which, 1}}, rest}

  # the target is required: `r1`, `r<3`, `ro>=19`
  defp reroll(how, line, [{:comparator, _, cmp}, {:int, _, n} | rest]),
    do: {:ok, {:modifier, line, {:reroll, how, comparator(cmp), List.to_integer(n)}}, rest}

  defp reroll(how, line, [{:int, _, n} | rest]),
    do: {:ok, {:modifier, line, {:reroll, how, :==, List.to_integer(n)}}, rest}

  defp reroll(_, _, _), do: :none

  defp comparator(~c"="), do: :==
  defp comparator(~c"<"), do: :<
  defp comparator(~c">"), do: :>
  defp comparator(~c"<="), do: :<=
  defp comparator(~c">="), do: :>=
end
