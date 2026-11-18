defmodule ExDiceRoller.Cache do
  @moduledoc """
  Functionality for managing caching for compiled roll functions.

  In many cases, ExDiceRoller can be used to compile a dice roll during project
  compilation, and using it within its local area, or pass it as an argument
  elsewhere. However, dice rolls can be generated during runtime. Repeated
  tokenizing, parsing, and compiling of runtime dice rolls can add up. The more
  complex the dice roll, the higher the cost.

  Local testing has revealed that there can be a relatively signifcant
  performance savings by caching compiled dice rolls and reusing the cached
  values instead of repeated interpretation. While these savings are on the
  order of microseconds (not milliseconds), they can add up in applications
  that have complex rules and are regularly generating dice rolls during
  runtime.

  In an effort to avoid this, ExDiceRoller allows for dice rolls to be cached
  and reused.

  ## Cache ownership

  Each cache is an ETS table owned by an `ExDiceRoller.Cache` process. The
  default cache (the `:cache_table` config, `ExDiceRoller.Cache` by default)
  starts with the `:ex_dice_roller` application, so `cache: true` works with
  no setup. Start more caches with `ExDiceRoller.start_cache/1`, which runs
  them under ExDiceRoller's own supervisor, or add `{ExDiceRoller.Cache,
  name: MyCache}` to your own supervision tree.

  If a cache process crashes, its supervisor restarts it with an empty table;
  rolls are compiled again on their next use.

      iex> ExDiceRoller.Cache.clear()
      iex> ExDiceRoller.Cache.all()
      []
      iex> ExDiceRoller.roll!("2d6+1d5", cache: true)
      9
      iex> [{"2d6+1d5", _}] = ExDiceRoller.Cache.all()
      iex> ExDiceRoller.roll!("2d6+1d5", cache: true)
      11
      iex> [{"2d6+1d5", _}] = ExDiceRoller.Cache.all()
      iex> ExDiceRoller.roll!("1d4+x", [x: 3, cache: true])
      7
      iex> [{"1d4+x", _}, {"2d6+1d5", _}] = ExDiceRoller.Cache.all()
      iex> ExDiceRoller.roll!("1d4+x", [x: 3, cache: true])
      7
  """

  use GenServer

  @cache_table Application.compile_env(:ex_dice_roller, :cache_table, ExDiceRoller.Cache)

  @type cache_entry :: {roll_string, roll_fun}
  @type roll_string :: String.t()
  @type roll_fun :: function

  @doc """
  Starts a process that creates and owns the cache table `name`, and links it
  to the caller. `opts` is a cache name, or a keyword list with `:name`; the
  default is the `:cache_table` config. The process is registered under the
  same name as the table.

  Use this from a supervisor (`{ExDiceRoller.Cache, name: MyCache}`). To
  start a cache from anywhere else, use `ExDiceRoller.start_cache/1`.
  """
  @spec start_link(atom | Keyword.t()) :: GenServer.on_start()
  def start_link(opts \\ [])

  def start_link(name) when is_atom(name), do: start_link(name: name)

  def start_link(opts) when is_list(opts) do
    name = Keyword.get(opts, :name, @cache_table)
    GenServer.start_link(__MODULE__, name, name: name)
  end

  @doc false
  def child_spec(opts) do
    name = if is_atom(opts), do: opts, else: Keyword.get(opts, :name, @cache_table)
    %{id: {__MODULE__, name}, start: {__MODULE__, :start_link, [opts]}}
  end

  @impl GenServer
  def init(name) do
    opts = [:public, :set, :named_table, {:read_concurrency, true}]
    ^name = :ets.new(name, opts)
    {:ok, name}
  end

  @doc "Retrieves all cached rolls."
  @spec all(atom | none) :: list(cache_entry)
  def all(cache \\ @cache_table), do: :ets.tab2list(cache)

  @doc """
  Looks up the roll in cache and returns `{:ok, fun}`. If the roll is not yet
  cached, it is compiled, cached, and returned. An invalid roll returns
  `{:error, %ExDiceRoller.Error{}}` and is not cached.
  """
  @spec obtain(atom | none, roll_string) :: {:ok, roll_fun} | {:error, ExDiceRoller.Error.t()}
  def obtain(cache \\ @cache_table, roll_string) do
    case get(cache, roll_string) do
      {:ok, _fun} = found ->
        found

      :not_found ->
        with {:ok, fun} <- ExDiceRoller.compile(roll_string) do
          :ok = put(cache, roll_string, fun)
          {:ok, fun}
        end
    end
  end

  @doc """
  Creates an entry in cache with `roll_string` as the key and `roll_fun` as the
  value.
  """
  @spec put(atom | none, roll_string, roll_fun) :: :ok
  def put(cache \\ @cache_table, roll_string, fun) when is_function(fun) do
    true = :ets.insert(cache, {roll_string, fun})
    :ok
  end

  @doc """
  Deletes the cache entry stored under `roll_string`. If `roll_string` is
  anything but a string, returns `{:error, %ExDiceRoller.Error{}}` with reason
  `:invalid_roll_key`.
  """
  @spec delete(atom | none, roll_string) :: :ok | {:error, ExDiceRoller.Error.t()}

  def delete(cache \\ @cache_table, roll_string)

  def delete(cache, roll_string) when is_bitstring(roll_string) do
    true = :ets.delete(cache, roll_string)
    :ok
  end

  def delete(_, roll_string),
    do: {:error, ExDiceRoller.Error.exception(reason: :invalid_roll_key, details: roll_string)}

  @doc """
  Empties the specified cache.
  """
  @spec clear(atom | none) :: :ok
  def clear(cache \\ @cache_table) do
    _ = :ets.delete_all_objects(cache)
    :ok
  end

  @spec get(atom, String.t()) :: {:ok, roll_fun} | :not_found
  defp get(cache, string) do
    case :ets.lookup(cache, string) do
      [{_, fun}] -> {:ok, fun}
      [] -> :not_found
    end
  end
end
