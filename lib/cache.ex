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

      iex> ExDiceRoller.start_cache()
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

  @cache_table Application.compile_env(:ex_dice_roller, :cache_table, ExDiceRoller.Cache)

  @type cache_entry :: {roll_string, roll_fun}
  @type roll_string :: String.t()
  @type roll_fun :: function

  @doc """
  Start the caching system, using the `:ex_dice_roller` config's `:cache_table`
  value.
  """
  @spec start_link() :: {:ok, atom}
  def start_link, do: start_link(@cache_table)

  @doc """
  Starts the caching system, using `name` for the cache table. Calling it again
  while the table exists is a no-op.
  """
  @spec start_link(atom) :: {:ok, atom}
  def start_link(name) do
    if :ets.whereis(name) == :undefined do
      opts = [:public, :set, :named_table, {:read_concurrency, true}]
      _ = :ets.new(name, opts)
    end

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
