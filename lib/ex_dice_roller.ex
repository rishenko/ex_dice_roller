defmodule ExDiceRoller do
  @moduledoc """
  Converts strings into dice rolls and returns expected results. Ignores any
  spaces, including tabs and newlines, in the provided string.

  ## Examples

      iex> ExDiceRoller.roll("1")
      1

      iex> ExDiceRoller.roll("1d8")
      1

      iex> ExDiceRoller.roll("2d20 + 5")
      34

      iex> ExDiceRoller.roll("2d8 + -5")
      0

      iex> ExDiceRoller.roll("(1d4)d(6*5) - (2/3+1)")
      18

      iex> ExDiceRoller.roll("1+2-3*4+5/6*7+8-9")
      -4

      iex> ExDiceRoller.roll("1+\t2*3d 4")
      15


  ## Order of Precedence

  The following table shows order of precendence, from highest to lowest,
  of the operators available to ExDiceRoller.


  Operator              | Associativity
  --------------------- | ------------
  `d`                   | left-to-right
  `+`, `-`              | unary
  `*`, `/`              | left-to-right
  `+`, `-`              | left-to-right

  ### Effects of Parentheses

  As in math, parentheses can be used to create sub-expressions.

      iex> ExDiceRoller.tokenize("1+3d4*1-2/-3") |> elem(1) |> ExDiceRoller.parse()
      {:ok,
      {{:operator, '-'},
        {{:operator, '+'}, {:digit, '1'},
        {{:operator, '*'}, {:roll, {:digit, '3'}, {:digit, '4'}}, {:digit, '1'}}},
        {{:operator, '/'}, {:digit, '2'}, {:digit, '-3'}}}}

      iex> ExDiceRoller.tokenize("(1+3)d4*1-2/-3") |> elem(1) |> ExDiceRoller.parse()
      {:ok,
      {{:operator, '-'},
        {{:operator, '*'},
        {:roll, {{:operator, '+'}, {:digit, '1'}, {:digit, '3'}}, {:digit, '4'}},
        {:digit, '1'}}, {{:operator, '/'}, {:digit, '2'}, {:digit, '-3'}}}}

      iex> ExDiceRoller.tokenize("1+3d(4*1)-2/-3") |> elem(1) |> ExDiceRoller.parse()
      {:ok,
      {{:operator, '-'},
        {{:operator, '+'}, {:digit, '1'},
        {:roll, {:digit, '3'}, {{:operator, '*'}, {:digit, '4'}, {:digit, '1'}}}},
        {{:operator, '/'}, {:digit, '2'}, {:digit, '-3'}}}}

      iex> ExDiceRoller.tokenize("1+3d4*(1-2)/-3") |> elem(1) |> ExDiceRoller.parse()
      {:ok,
      {{:operator, '+'}, {:digit, '1'},
        {{:operator, '/'},
        {{:operator, '*'}, {:roll, {:digit, '3'}, {:digit, '4'}},
          {{:operator, '-'}, {:digit, '1'}, {:digit, '2'}}}, {:digit, '-3'}}}}


  ## Compiled Rolls

  Some systems utilize complex dice rolling equations. Repeatedly tokenizing,
  parsing, and interpreting complicated dice rolls strings can lead to a
  performance hit on an application. To ease the burden, developers can
  _compile_ a dice roll string into an anonymous function. This anonymous
  function can be cached and reused repeatedly without having to re-parse the
  string, nor re-interpret the parsed expression.

      iex> {:ok, roll_fun} = ExDiceRoller.compile("2d6+3")
      iex> ExDiceRoller.execute(roll_fun)
      8
      iex> ExDiceRoller.execute(roll_fun)
      13
      iex> ExDiceRoller.execute(roll_fun)
      10
      iex> ExDiceRoller.execute(roll_fun)
      11
  """

  alias ExDiceRoller.Compiler

  @type tokens :: [token, ...]
  @type token :: {token_type, integer, list}
  @type token_type :: :digit | :basic_operator | :complex_operator | :roll | :"(" | :")"

  @type expression ::
          {:digit, list}
          | {{:operator, list}, expression, expression}
          | {:roll, expression, expression}

  @doc """
  Processes a given string as a dice roll and returns the final result. Note
  that the final result is a rounded integer.

      iex> ExDiceRoller.roll("1d6+15")
      18
  """
  @spec roll(String.t()) :: integer
  def roll(roll_string) do
    with {:ok, tokens} <- tokenize(roll_string),
         {:ok, parsed_tokens} <- parse(tokens) do
      parsed_tokens
      |> calculate()
      |> round()
    else
      {:error, _} = err -> err
    end
  end

  @doc """
  Converts a roll-based string into tokens using leex. The input definition
  file is located at `src/dice_lexer.xrl`. See `t:token_type/0`, `t:token/0`,
  and `t:tokens/0` for the possible return values.

      iex> ExDiceRoller.tokenize("2d8+3")
      {:ok,
      [
        {:digit, 1, '2'},
        {:roll, 1, 'd'},
        {:digit, 1, '8'},
        {:basic_operator, 1, '+'},
        {:digit, 1, '3'}
      ]}
  """
  @spec tokenize(String.t()) :: {:ok, tokens}
  def tokenize(roll_string) do
    with charlist <- String.to_charlist(roll_string),
         {:ok, tokens, _} <- :dice_lexer.string(charlist) do
      {:ok, tokens}
    else
      {:error, {1, :dice_lexer, reason}, 1} ->
        {:error, {:tokenizing_failed, reason}}
    end
  end

  @doc """
  Converts a series of tokens provided by `tokenize/1` and parses them into
  an expression structure. This expression structure is what's used by the
  dice rolling functions to calculate rolls. The BNF grammar definition
  file is located at `src/dice_parser.yrl`.

      iex> {:ok, tokens} = ExDiceRoller.tokenize("2d8 + (1+2)")
      {:ok,
      [
        {:digit, 1, '2'},
        {:roll, 1, 'd'},
        {:digit, 1, '8'},
        {:basic_operator, 1, '+'},
        {:"(", 1, '('},
        {:digit, 1, '1'},
        {:basic_operator, 1, '+'},
        {:digit, 1, '2'},
        {:")", 1, ')'}
      ]}
      iex> {:ok, _} = ExDiceRoller.parse(tokens)
      {:ok,
      {{:operator, '+'}, {:roll, {:digit, '2'}, {:digit, '8'}},
        {{:operator, '+'}, {:digit, '1'}, {:digit, '2'}}}}

  """
  @spec parse(tokens) :: {:ok, expression}
  def parse(tokens) do
    case :dice_parser.parse(tokens) do
      {:ok, _} = resp -> resp
      {:error, {_, :dice_parser, reason}} -> {:error, {:token_parsing_failed, reason}}
    end
  end

  @doc """
  Takes a given expression from parse and calculates the result.
  """
  @spec calculate(expression) :: integer | float
  def calculate(expression) do
    expression
    |> compile()
    |> elem(1)
    |> execute()
  end

  @doc """
  Compiles a string or `t:expression/0` into an anonymous function.

      iex> {:ok, roll_fun} = ExDiceRoller.compile("1d8+2d(5d3+4)/3")
      iex> ExDiceRoller.execute(roll_fun)
      5.0
  """
  @spec compile(String.t() | expression) :: {:ok, Compiler.compiled_function()} | {:error, any}
  def compile(roll_string) when is_bitstring(roll_string) do
    with {:ok, tokens} <- tokenize(roll_string),
         {:ok, parsed_tokens} <- parse(tokens) do
      compile(parsed_tokens)
    else
      {:error, _} = err -> err
    end
  end

  def compile(expression) when is_tuple(expression) do
    compiled = Compiler.compile(expression)

    case is_function(compiled) do
      false -> {:ok, fn -> compiled end}
      true -> {:ok, compiled}
    end
  end

  @doc "Executes a function built by `compile/1`."
  @spec execute(function) :: integer | float
  def execute(compiled) when is_function(compiled) do
    compiled.()
  end
end
