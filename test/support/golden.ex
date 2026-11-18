defmodule ExDiceRoller.Golden do
  @moduledoc """
  Golden-master harness. Replays a fixed corpus of roll expressions under
  several option sets with fixed RNG seeds, and renders each case as one line
  of text. `test/golden/results.tsv` holds the lines recorded from the
  original 2018 code; `ExDiceRoller.GoldenTest` checks that the current code
  still produces them.

  Each line is `<expr index>/<option set index>`, the inspected expression,
  then three results:

  1. `ExDiceRoller.roll/2`
  2. `ExDiceRoller.roll/2` with `cache: true` (same seed)
  3. `ExDiceRoller.compile/1`, reduced to `:ok` or `:error`

  Exceptions are rendered as `RAISE <module>`. `ArgumentError` messages come
  from ExDiceRoller itself, so they are kept; other messages come from Elixir
  or OTP internals and vary between versions, so they are dropped.

  The results were recorded from the 1.x API, where `roll/2` returned bare
  values, returned `{:error, {:tokenizing_failed | :token_parsing_failed, _}}`
  for bad syntax, and raised `ArgumentError` for failed rolls. Since 2.0,
  `roll/2` returns `{:ok, _}` or `{:error, %ExDiceRoller.Error{}}`, so
  `to_1x/1` converts each 2.0 result back into its 1.x form before rendering.
  That keeps the recording comparable: only the shape of the return value
  changed, and any difference in values or error messages still shows up.

  To re-record after an intentional behavior change, run
  `MIX_ENV=test mix run test/golden/record.exs` and review the diff.
  """

  @dir Path.expand("../golden", __DIR__)
  @expressions_path Path.join(@dir, "expressions.exs")
  @results_path Path.join(@dir, "results.tsv")

  # every single-letter variable except `d`, with values 1..5
  @vars for c <- ?a..?z, c != ?d, do: {List.to_atom([c]), rem(c, 5) + 1}

  @option_sets [
    [],
    [opts: :explode],
    [opts: :keep],
    [opts: [:keep, :lowest]],
    [opts: [:highest]],
    [opts: :keep, drop_lowest: true, >=: 2]
  ]

  def results_path, do: @results_path

  # Dice modifiers postdate the original corpus, so they have their own
  # recording, made on 2026-11-18 before the plain and modified dice paths in
  # `ExDiceRoller.Compilers.Roll` were merged. It covers every combination of
  # these counts, sides, modifiers, options and variable values.
  @modifiers_path Path.join(@dir, "modifiers.tsv")
  @counts ["0", "1", "2.4", "4", "10", "x"]
  @sides ["0", "1", "2", "6", "20", "y"]
  @modifiers [
    "",
    "kh3",
    "kl",
    "dh1",
    "dl2",
    "r1",
    "ro<3",
    "!",
    "r1!",
    "kh2dl1",
    "r>4",
    "!kh1",
    "r<6"
  ]
  @modifier_opts [[], [opts: :keep], [opts: :explode], [opts: [:keep, :explode]]]
  @modifier_vars [[x: 3, y: 4], [x: [1, 2], y: [2, 6]], [x: 0.5, y: 1]]

  def modifiers_path, do: @modifiers_path

  @spec modifiers_recorded() :: [String.t()]
  def modifiers_recorded do
    @modifiers_path |> File.read!() |> String.split("\n", trim: true)
  end

  @doc """
  Runs the modifier corpus and returns one line per case: the case, the
  result or error, and a hash of the random number state afterwards, which
  changes if a die is drawn more or fewer times.
  """
  @spec modifiers_run() :: [String.t()]
  def modifiers_run do
    for c <- @counts,
        s <- @sides,
        {m, k} <- Enum.with_index(@modifiers),
        {o, j} <- Enum.with_index(@modifier_opts),
        {v, i} <- Enum.with_index(@modifier_vars) do
      expr = c <> "d" <> s <> m
      :rand.seed(:exsss, {k, j, i})

      result =
        case ExDiceRoller.roll(expr, v ++ o) do
          {:ok, val} -> inspect(val, limit: :infinity)
          {:error, e} -> "ERROR #{e.reason}: #{e.message}"
        end

      Enum.join([expr, "#{j}/#{i}", result, :erlang.phash2(:rand.export_seed())], "\t")
    end
  end

  @spec expressions() :: [String.t()]
  def expressions do
    {exprs, _} = Code.eval_file(@expressions_path)
    exprs
  end

  @spec recorded() :: [String.t()]
  def recorded do
    @results_path |> File.read!() |> String.split("\n", trim: true)
  end

  @doc "Runs the whole corpus and returns one line per case."
  @spec run() :: [String.t()]
  def run do
    {:ok, _} = ExDiceRoller.start_cache()
    :ok = ExDiceRoller.Cache.clear()

    for {expr, i} <- Enum.with_index(expressions()),
        {opts, j} <- Enum.with_index(@option_sets) do
      args = @vars ++ opts
      :rand.seed(:exsss, {i, j, 7})
      direct = render(fn -> to_1x(ExDiceRoller.roll(expr, args)) end)
      :rand.seed(:exsss, {i, j, 7})
      cached = render(fn -> to_1x(ExDiceRoller.roll(expr, args ++ [cache: true])) end)
      compiled = render(fn -> expr |> ExDiceRoller.compile() |> elem(0) end)
      Enum.join(["#{i}/#{j}", inspect(expr), direct, cached, compiled], "\t")
    end
  end

  @parse_reasons [:tokenizing_failed, :token_parsing_failed]

  @spec to_1x({:ok, any} | {:error, ExDiceRoller.Error.t()}) :: any
  defp to_1x({:ok, value}), do: value

  defp to_1x({:error, %ExDiceRoller.Error{reason: reason, details: details}})
       when reason in @parse_reasons,
       do: {:error, {reason, details}}

  defp to_1x({:error, %ExDiceRoller.Error{reason: :arithmetic_error, details: e}}), do: raise(e)
  defp to_1x({:error, %ExDiceRoller.Error{message: message}}), do: raise(ArgumentError, message)

  defp render(fun) do
    inspect(fun.(), limit: :infinity)
  rescue
    e in ArgumentError -> "RAISE ArgumentError " <> Exception.message(e)
    e -> "RAISE " <> inspect(e.__struct__)
  end
end
