defmodule ExDiceRoller do
  @moduledoc """
  Converts strings into dice rolls and returns expected results. Ignores any
  spaces, including tabs and newlines, in the provided string. A roll can be
  invoked via `ExDiceRoller.roll/2`.

      iex> ExDiceRoller.roll("2d6+3")
      8

      iex> ExDiceRoller.roll("(1d4)d(6*y)-(2/3+1dx)", [x: 2, y: 3])
      11

      iex> import ExDiceRoller.Sigil
      iex> ExDiceRoller.roll(~a/1d2+z/, [z: ~a/1d2/, opts: [:explode]])
      8


  Rolls and invoked compiled functions can be supplied a number of options:

  * `:cache`: Performs a cache lookup, with a miss generating a compiled
  roll that is both cached and returned.
  `ExDiceRoller.Cache.obtain/2` for more information.
  * `:explode`: Causes dice to _explode_. This means that if a die roll results
  in the highest possible value for a die (such as rolling a 20 on a d20), the
  die will be rerolled until the result is no longer the max possible. It then
  sums the total of all rolls and returns that value.
  * `:keep`: Retains each dice roll.
  For more information, see `ExDiceRoller.Compilers.Roll`.
  * `:highest`: compares and selects the highest value(s) from a set of
  expressions separated by the `,` operator
  * `:lowest`: compares and selects the lowest value(s) from a set of
  expressions separated by the `,` operator


  ## Order of Precedence

  The following table shows order of precendence, from highest to lowest,
  of the operators available to ExDiceRoller.


  Operator              | Associativity | Compiler
  --------------------- | ------------- | ----------------------------
  `d`                   | left-to-right | `ExDiceRoller.Compilers.Roll`
  `+`, `-`              | unary         | NA (handled by the parser in `dice_parser.yrl`)
  `*`, `/`, `%`, `^`    | left-to-right | `ExDiceRoller.Compilers.Math`
  `+`, `-`              | left-to-right | `ExDiceRoller.Compilers.Math`
  `,`                   | left-to-right | `ExDiceRoller.Compilers.Separator`

  ### Effects of Parentheses

  As in math, parentheses can be used to create sub-expressions.

      iex> ExDiceRoller.tokenize("1+3d4*1-2/-3") |> elem(1) |> ExDiceRoller.parse()
      {:ok,
      {{:operator, '-'},
        {{:operator, '+'}, 1,
        {{:operator, '*'}, {:roll, 3, 4}, 1}},
        {{:operator, '/'}, 2, -3}}}

      iex> ExDiceRoller.tokenize("(1+3)d4*1-2/-3") |> elem(1) |> ExDiceRoller.parse()
      {:ok,
      {{:operator, '-'},
        {{:operator, '*'},
        {:roll, {{:operator, '+'}, 1, 3}, 4},
        1}, {{:operator, '/'}, 2, -3}}}

      iex> ExDiceRoller.tokenize("1+3d(4*1)-2/-3") |> elem(1) |> ExDiceRoller.parse()
      {:ok,
      {{:operator, '-'},
        {{:operator, '+'}, 1,
        {:roll, 3, {{:operator, '*'}, 4, 1}}},
        {{:operator, '/'}, 2, -3}}}

      iex> ExDiceRoller.tokenize("1+3d4*(1-2)/-3") |> elem(1) |> ExDiceRoller.parse()
      {:ok,
      {{:operator, '+'}, 1,
        {{:operator, '/'},
        {{:operator, '*'}, {:roll, 3, 4},
          {{:operator, '-'}, 1, 2}}, -3}}}


  ## Compiled Rolls

  Some systems utilize complex dice rolling equations. Repeatedly tokenizing,
  parsing, and interpreting complicated dice rolls strings can lead to a
  performance hit on an application. To ease the burden, developers can
  _compile_ a dice roll string into an anonymous function. This anonymous
  function can be passed around as any other function and reused repeatedly
  without having to re-tokenize the string, nor re-interpret a parsed
  expression.

      iex> {:ok, roll_fun} = ExDiceRoller.compile("2d6+3")
      iex> ExDiceRoller.execute(roll_fun)
      8
      iex> ExDiceRoller.execute(roll_fun)
      13
      iex> ExDiceRoller.execute(roll_fun)
      10

  More information can be found in `ExDiceRoller.Compiler`.


  ## Variables

  Single-letter variables can be used when compiling dice rolls. However, values
  for those variables must be supplied upon invocation. Values can be any of the
  following:

  * numbers
  * expressions, such as "1d6+2"
  * compiled dice rolls
  * results of `~a` sigil, as described in `ExDiceRoller.Sigil`
  * lists of any of the above

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

  More information can be found in `ExDiceRoller.Compilers.Variable`.


  ## Caching

  ExDiceRoller can cache and reuse dice rolls.

      iex> ExDiceRoller.start_cache()
      iex> ExDiceRoller.roll("8d6-(4d5)", opts: [cache: true])
      20
      iex> ExDiceRoller.roll("8d6-(4d5)", opts: [cache: true])
      13
      iex> ExDiceRoller.roll("1d3+x", [x: 4, cache: true])
      6
      iex> ExDiceRoller.roll("1d3+x", [x: 1, opts: [:cache, :explode]])
      6

  More details can be found in the documentation for `ExDiceRoller.Cache`.


  ## Sigil Support

  ExDiceRoller comes with its own sigil, `~a`, that can be used to create
  compiled dice roll functions or roll them on the spot.

      iex> import ExDiceRoller.Sigil
      iex> fun = ~a/2d6+2/
      iex> ExDiceRoller.roll(fun)
      7
      iex> ExDiceRoller.roll(~a|1d4+x/5|, [x: 43])
      11
      iex> ExDiceRoller.roll(~a/xdy/, [x: fun, y: ~a/12d4-15/])
      111

  More information can be found in `ExDiceRoller.Sigil`.


  ## ExDiceRoller Examples

  The following examples show a variety of types of rolls, and includes examples
  of basic and complex rolls, caching, sigil support, variables, and
  combinations of thereof.

      iex> ExDiceRoller.roll("1d8")
      1

      iex> ExDiceRoller.roll("2d20 + 5")
      34

      iex> import ExDiceRoller.Sigil
      iex> ExDiceRoller.roll(~a/2d8-2/)
      3

      iex> ExDiceRoller.roll("(1d4)d(6*5) - (2/3+1)")
      18

      iex> ExDiceRoller.roll("1+\t2*3d 4")
      15

      iex> ExDiceRoller.roll("1dx+6-y", [x: 10, y: 5])
      10

      iex> import ExDiceRoller.Sigil
      iex> ExDiceRoller.roll(~a/2+5dx/, x: ~a|3d(7/2)|)
      19

      iex> ExDiceRoller.roll("1d2", opts: [:explode])
      1
      iex> ExDiceRoller.roll("1d2", opts: [:explode])
      7

      iex> ExDiceRoller.start_cache()
      iex> ExDiceRoller.roll("1d2+x", [x: 3, cache: true])
      4
      iex> ExDiceRoller.roll("1d2+x", [x: 3, cache: true, opts: :explode])
      10

      iex> import ExDiceRoller.Sigil
      iex> ~a/1d2+3/r
      4
      iex> ~a/1d2+2/re
      9
  """

  alias ExDiceRoller.{Args, Cache, Compiler, Parser, Tokenizer}

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
  def roll(roll_string), do: roll(roll_string, opts: [])

  @doc """
  Processes a given string as a dice roll and returns the calculated result. The
  result is a rounded integer.

  Any variable values should be specified in `vars`. Options can be passed in
  `opts`.

  Possible values for `opts` include:
  * `:cache`: Performs a cache lookup, with a miss generating a compiled
  roll that is both cached and returned.
  `ExDiceRoller.Cache.obtain/2` for more information.
  * `:explode`: Causes dice to _explode_. This means that if a die roll results
  in the highest possible value for a die (such as rolling a 20 on a d20), the
  die will be rerolled until the result is no longer the max possible. It then
  sums the total of all rolls and returns that value.
  * `:keep`: Retains each dice roll.
  For more information, see `ExDiceRoller.Compilers.Roll`.
  * `:highest`: Selects the highest of all calculated values when using the `,`
  operator.
  * `:lowest`: Selects the lowest of all calculated values when using the `,`
  operator.

  ### Examples

      iex> ExDiceRoller.roll("1+x", [x: 1])
      2

      iex> ExDiceRoller.roll("1d6+15", [])
      18

      iex> ExDiceRoller.roll("1d8+x", [x: 5])
      6

      iex> ExDiceRoller.roll("1d3", opts: :explode)
      5

      iex> ExDiceRoller.start_cache(ExDiceRoller.Cache)
      iex> ExDiceRoller.roll("(1d6)d4-3+y", [y: 3, cache: true])
      10
      iex> ExDiceRoller.roll("1d2+y", y: 1, cache: true, opts: [:explode])
      2
      iex> ExDiceRoller.roll("1d2+y", y: 2, cache: true, opts: [:explode])
      11

      iex> ExDiceRoller.roll("1,2", opts: [:highest])
      2
      iex> ExDiceRoller.roll("10,12,45,3,100", opts: [:lowest])
      3

  """
  @spec roll(String.t() | Compiler.compiled_fun(), Keyword.t()) :: integer

  def roll(roll_string, args) when is_bitstring(roll_string) do
    case Args.use_cache?(args) do
      false ->
        with {:ok, tokens} <- Tokenizer.tokenize(roll_string),
             {:ok, parsed_tokens} <- Parser.parse(tokens) do
          calculate(parsed_tokens, args)
        else
          {:error, _} = err -> err
        end

      true ->
        @cache_table
        |> Cache.obtain(roll_string)
        |> execute(args)
    end
  end

  def roll(compiled, args) when is_function(compiled) do
    execute(compiled, args)
  end

  @doc "Helper function that calls `ExDiceRoller.Tokenizer.tokenize/1`."
  @spec tokenize(String.t()) :: {:ok, Tokenizer.tokens()}
  def tokenize(roll_string), do: Tokenizer.tokenize(roll_string)

  @doc "Helper function that calls `ExDiceRoller.Tokenizer.tokenize/1`."
  @spec parse(Tokenizer.tokens()) :: {:ok, Parser.expression()}
  def parse(tokens), do: Parser.parse(tokens)

  @doc """
  Takes an `t:ExDiceRoller.Parser.expression/0` from parse and calculates the result.
  """
  @spec calculate(Parser.expression(), Keyword.t()) :: number
  def calculate(expression, args) do
    expression
    |> compile()
    |> elem(1)
    |> execute(args)
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

  def compile(roll) when is_tuple(roll) or is_number(roll) do
    {:ok, Compiler.compile(roll)}
  end

  def compile(other), do: {:error, {:cannot_compile_roll, other}}

  @doc "Executes a function built by `compile/1`."
  @spec execute(function, Keyword.t()) :: integer | list(integer)
  def execute(compiled, args \\ []) when is_function(compiled) do
    compiled.(args)
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
