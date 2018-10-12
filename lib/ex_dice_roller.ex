defmodule ExDiceRoller do
  @moduledoc """
  Converts strings into dice rolls and returns expected results. Ignores any
  spaces, including tabs and newlines, in the provided string.

      iex> ExDiceRoller.roll("2d6+3")
      8

      iex> ExDiceRoller.roll("(1d4)d(6*y)-(2/3+1dx)", [x: 2, y: 3])
      11

      iex> import ExDiceRoller.Sigil
      iex> ExDiceRoller.roll(~a/1d2+z/, [z: ~a/1d2/], [:explode])
      8

  ## Order of Precedence

  The following table shows order of precendence, from highest to lowest,
  of the operators available to ExDiceRoller.


  Operator              | Associativity
  --------------------- | ------------
  `d`                   | left-to-right
  `+`, `-`              | unary
  `*`, `/`, `%`, `^`    | left-to-right
  `+`, `-`              | left-to-right
  `,`                   | left-to-right

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


  ## Variables

  Single-letter variables can be used when compiling dice rolls. However, values
  for those variables must be supplied upon invocation. Values can be any of the
  following:

  * numbers
  * expressions, such as "1d6+2"
  * previously compiled dice rolls
  * `~a` sigil, as described in `ExDiceRoller.Sigil`

      ```elixir
      iex> {:ok, fun} = ExDiceRoller.compile("2d4+x")
      iex> ExDiceRoller.execute(fun, x: 2)
      7
      iex> ExDiceRoller.execute(fun, x: "5d100")
      245
      iex> {:ok, fun_2} = ExDiceRoller.compile("3d8-2")
      iex> ExDiceRoller.execute(fun, x: fun_2)
      23
      iex> import ExDiceRoller.Sigil
      iex> ExDiceRoller.execute(fun, x: ~a/3d5+2d4/)
      22
      ```


  ## Caching

  ExDiceRoller can cache and reuse dice rolls.

      iex> ExDiceRoller.start_cache()
      iex> ExDiceRoller.roll("8d6-(4d5)", [], [:cache])
      20
      iex> ExDiceRoller.roll("8d6-(4d5)", [], [:cache])
      13
      iex> ExDiceRoller.roll("1d3+x", [x: 4], [:cache])
      6
      iex> ExDiceRoller.roll("1d3+x", [x: 1], [:cache, :explode])
      6

  More details can be found in the documentation for `ExDiceRoller.Cache`.


  ## Sigil Support

  ExDiceRoller comes with its own sigil, `~a`, that can be used to create
  compiled dice roll functions or roll them on the spot. See
  `ExDiceRoller.Sigil` for detailed usage and examples.

      iex> import ExDiceRoller.Sigil
      iex> fun = ~a/2d6+2/
      iex> ExDiceRoller.roll(fun)
      7
      iex> ExDiceRoller.roll(~a|1d4+x/5|, [x: 43])
      11
      iex> ExDiceRoller.roll(~a|xdy|, [x: fun, y: ~a/12d4-15/])
      111


  ## ExDiceRoller Examples

  The following examples show a variety of types of rolls, and includes examples
  of basic and complex rolls, caching, sigil support, variables, and
  combinations of thereof.

      iex> ExDiceRoller.roll("1")
      1

      iex> ExDiceRoller.roll("1d8")
      1

      iex> ExDiceRoller.roll("2d20 + 5")
      34

      iex> import ExDiceRoller.Sigil
      iex> ExDiceRoller.roll(~a/2d8-2/)
      3

      iex> ExDiceRoller.roll("(1d4)d(6*5) - (2/3+1)")
      18

      iex> ExDiceRoller.roll("1+2-3*4+5/6*7+8-9")
      -4

      iex> ExDiceRoller.roll("1+\t2*3d 4")
      15

      iex> ExDiceRoller.roll("1dx+6-y", x: 10, y: 5)
      10

      iex> import ExDiceRoller.Sigil
      iex> ExDiceRoller.roll(~a/2+5dx/, x: ~a|3d(7/2)|)
      19

      iex> ExDiceRoller.roll("1d2", [], [:explode])
      1
      iex> ExDiceRoller.roll("1d2", [], [:explode])
      7

      iex> ExDiceRoller.start_cache()
      iex> ExDiceRoller.roll("1d2+x", [x: 3], [:cache])
      4
      iex> ExDiceRoller.roll("1d2+x", [x: 3], [:cache, :explode])
      10

      iex> import ExDiceRoller.Sigil
      iex> ~a/1d2+3/r
      4
      iex> ~a/1d2+2/re
      9

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
  @spec roll(String.t()) :: integer | list(integer)
  def roll(roll_string), do: roll(roll_string, [], [])

  @doc """
  Processes a given string as a dice roll and returns the calculated result. The
  result is a rounded integer.

  Any variable values should be specified in `args`. Options can be passed in
  `opts`.

  Possible values for `opts` include:
  * `:cache`: Performs a cache lookup, with a miss generating a compiled
  roll that is both cached and returned.
  `ExDiceRoller.Cache.obtain/2` for more information.
  * `:explode`: Causes dice to _explode_. This means that if a die roll results
  in the highest possible value for a die (such as rolling a 20 on a d20), the
  die will be rerolled until the result is no longer the max possible. It then
  sums the total of all rolls and returns that value.
  * `:highest`: Selects the highest of all calculated values when using the `,`
  operator.
  * `:lowest`: Selects the lowest of all calculated values when using the `,`
  operator.

  ### Examples

      iex> ExDiceRoller.roll("1d6+15", [])
      18

      iex> ExDiceRoller.roll("1d8+x", x: 5)
      6

      iex> ExDiceRoller.roll("1d3", [], [:explode])
      5
      iex> ExDiceRoller.roll("1d3", [], [:explode])
      4
      iex> ExDiceRoller.roll("1d3", [], [:explode])
      2

      iex> ExDiceRoller.start_cache(ExDiceRoller.Cache)
      iex> ExDiceRoller.roll("(1d6)d4-3+y", [y: 3], [:cache])
      10
      iex> ExDiceRoller.roll("1d2+y", [y: 1], [:cache, :explode])
      2
      iex> ExDiceRoller.roll("1d2+y", [y: 2], [:cache, :explode])
      11

      iex> ExDiceRoller.roll("1,2", [], [:highest])
      2
      iex> ExDiceRoller.roll("10,12,45,3,100", [], [:lowest])
      3

  """
  @spec roll(String.t() | Compiler.compiled_fun(), Keyword.t(), list(atom | tuple)) :: integer

  def roll(roll_string, args, opts \\ [])

  def roll(roll_string, args, [:cache | rest]) do
    @cache_table
    |> Cache.obtain(roll_string)
    |> execute(args, rest)
  end

  def roll(roll_string, args, opts) when is_bitstring(roll_string) do
    with {:ok, tokens} <- Tokenizer.tokenize(roll_string),
         {:ok, parsed_tokens} <- Parser.parse(tokens) do
      calculate(parsed_tokens, args, opts)
    else
      {:error, _} = err -> err
    end
  end

  def roll(compiled, args, opts) when is_function(compiled) do
    execute(compiled, args, opts)
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
      5

  If `roll` is not a string or expression compile/1 will return
  `{:error, {:cannot_compile_roll, other}}`.

  """
  @spec compile(String.t() | Parser.expression()) ::
          {:ok, Compiler.compiled_function()} | {:error, any}
  def compile(roll)

  def compile(roll) when is_bitstring(roll) do
    with {:ok, tokens} <- Tokenizer.tokenize(roll),
         {:ok, parsed_tokens} <- Parser.parse(tokens) do
      compile(parsed_tokens)
    else
      {:error, _} = err -> err
    end
  end

  def compile(roll) when is_tuple(roll) do
    {:ok, Compiler.compile(roll)}
  end

  def compile(other), do: {:error, {:cannot_compile_roll, other}}

  @doc "Executes a function built by `compile/1`."
  @spec execute(function, Compiler.args(), Compiler.opts()) :: integer | list(integer)
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
