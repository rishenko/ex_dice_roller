defmodule ExDiceRoller.Cache do
  @moduledoc """
  Functionality for managing caching for compiled roll functions.
  """

  @cache_table Application.fetch_env!(:ex_dice_roller, :cache_table)

  @type cache_entry :: {roll_string, roll_fun}
  @type roll_string :: String.t()
  @type roll_fun :: function

  @doc """
  Start the caching system, using the `:ex_dice_roller` config's `:cache_table`
  value.
  """
  @spec start_link() :: {:ok, atom}
  def start_link, do: start_link(@cache_table)

  @doc "Starts the caching system, using `name` for the cache table."
  @spec start_link(atom) :: {:ok, atom}
  def start_link(name) do
    opts = [:public, :set, :named_table, {:read_concurrency, true}]
    _ = :ets.new(name, opts)
    {:ok, name}
  end

  @doc "Retrieves all cached rolls."
  @spec all(atom | none) :: list(cache_entry)
  def all(cache \\ @cache_table), do: :ets.tab2list(cache)

  @doc """
  Looks up the roll in cache and returns its compiled function. Note that if
  the roll is not yet cached, it will be compiled, cached, and the compiled
  function returned.
  """
  @spec obtain(atom | none, roll_string) :: roll_fun
  def obtain(cache \\ @cache_table, roll_string) do
    case get(cache, roll_string) do
      {:ok, fun} ->
        fun

      {:error, :fun_not_found} ->
        case ExDiceRoller.compile(roll_string) do
          {:ok, fun} ->
            :ok = put(cache, roll_string, fun)
            fun

          {:error, _} = err ->
            err
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
  Deletes the cache entry stored under `roll_string`. Note that if `roll_string`
  is anything but a string, `{:error, {:invalid_roll_string, roll_string}}`
  will be returned.
  """
  @spec delete(atom | none, roll_string) :: :ok | {:error, {:invalid_roll_string, any}}

  def delete(cache \\ @cache_table, roll_string)

  def delete(cache, roll_string) when is_bitstring(roll_string) do
    true = :ets.delete(cache, roll_string)
    :ok
  end

  def delete(_, roll_string), do: {:error, {:invalid_roll_string, roll_string}}

  @doc """
  Empties the specified cache.
  """
  @spec clear(atom | none) :: :ok
  def clear(cache \\ @cache_table) do
    _ = :ets.delete_all_objects(cache)
    :ok
  end

  @spec get(atom, String.t()) :: {:ok, roll_fun} | {:error, :fun_not_found}
  defp get(cache, string) do
    case :ets.lookup(cache, string) do
      [{_, fun}] -> {:ok, fun}
      [] -> {:error, :fun_not_found}
    end
  end
end
