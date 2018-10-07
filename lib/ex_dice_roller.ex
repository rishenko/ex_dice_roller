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

      iex> ExDiceRoller.roll("1dx+6-y", x: 10, y: 5)
      10

      iex> ExDiceRoller.roll("1d2", [], [:explode])
      1
      iex> ExDiceRoller.roll("1d2", [], [:explode])
      7

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

  alias ExDiceRoller.{Cache, Compiler, Parser, Tokenizer}

  @cache_table Application.fetch_env!(:ex_dice_roller, :cache_table)

  @doc """
  Processes a given string as a dice roll and returns the final result. The
  final result is a rounded integer.

      iex> ExDiceRoller.roll("1d6+15")
      18


  Note that using variables with this call will result in errors. If you need
  variables, use `roll/3` instead.
  """
  @spec roll(String.t()) :: integer
  def roll(roll_string), do: roll(roll_string, [], [])

  @doc """
  Processes a given string as a dice roll and returns the final result. The
  final result is a rounded integer.

  Any variables should be specified in `args`. Options can be passed in `opts`.

  Possible options include:
  * `:cache`: This will add compiled function caching. Refer to
  `ExDiceRoller.Cache.obtain/2` for more information.

  ### Examples

      iex> ExDiceRoller.roll("1d6+15", [])
      18

      iex> ExDiceRoller.roll("1d8+x", x: 5)
      6

      iex> ExDiceRoller.start_cache(ExDiceRoller.Cache)
      iex> ExDiceRoller.roll("(1d6)d4-3+y", [y: 3], [:cache])
      10

  """
  @spec roll(String.t(), Keyword.t(), list(atom | tuple)) :: integer

  def roll(roll_string, args, opts \\ [])

  def roll(roll_string, args, [:cache | rest]) do
    @cache_table
    |> Cache.obtain(roll_string)
    |> execute(args, rest)
  end

  def roll(roll_string, args, opts) do
    with {:ok, tokens} <- Tokenizer.tokenize(roll_string),
         {:ok, parsed_tokens} <- Parser.parse(tokens) do
      parsed_tokens
      |> calculate(args, opts)
      |> round()
    else
      {:error, _} = err -> err
    end
  end

  @doc "Helper function that calls `ExDiceRoller.Tokenizer.tokenize/1`."
  @spec tokenize(String.t()) :: {:ok, Tokenizer.tokens()}
  def tokenize(roll_string), do: Tokenizer.tokenize(roll_string)

  @doc "Helper function that calls `ExDiceRoller.Tokenizer.tokenize/1`."
  @spec parse(Tokenizer.tokens()) :: {:ok, Parser.expression()}
  def parse(tokens), do: Parser.parse(tokens)

  @doc """
  Takes a given expression from parse and calculates the result.
  """
  @spec calculate(Parser.expression(), Compiler.args(), Compiler.opts()) :: number
  def calculate(expression, args \\ [], opts \\ []) do
    expression
    |> compile()
    |> elem(1)
    |> execute(args, opts)
  end

  @doc """
  Compiles a string or `t:expression/0` into an anonymous function.

      iex> {:ok, roll_fun} = ExDiceRoller.compile("1d8+2d(5d3+4)/3")
      iex> ExDiceRoller.execute(roll_fun)
      5.0

  """
  @spec compile(String.t() | Parser.expression()) ::
          {:ok, Compiler.compiled_function()} | {:error, any}
  def compile(roll)

  def compile(roll_string) when is_bitstring(roll_string) do
    with {:ok, tokens} <- Tokenizer.tokenize(roll_string),
         {:ok, parsed_tokens} <- Parser.parse(tokens) do
      compile(parsed_tokens)
    else
      {:error, _} = err -> err
    end
  end

  def compile(expression) when is_tuple(expression) do
    compiled = Compiler.compile(expression)

    case is_function(compiled) do
      false -> {:ok, fn _args, _opts -> compiled end}
      true -> {:ok, compiled}
    end
  end

  def compile(other), do: {:error, {:invalid_roll_string, other}}

  @doc "Executes a function built by `compile/1`."
  @spec execute(function, Compiler.args(), Compiler.opts()) :: number
  def execute(compiled, args \\ [], opts \\ []) when is_function(compiled) do
    compiled.(args, opts)
  end

  @doc """
  Starts the underlying roll function cache. See `ExDiceRoller.Cache` for more
  details.
  """
  @spec start_cache(atom | none) :: {:ok, any}
  def start_cache(cache \\ @cache_table) do
    {:ok, _} = Cache.start_link(cache)
  end
end
