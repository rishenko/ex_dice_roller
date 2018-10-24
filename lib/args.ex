defmodule ExDiceRoller.Args do
  @moduledoc "Manages arguments used in ExDiceRoller rolls."

  alias ExDiceRoller.Filters

  @spec use_cache?(Keyword.t()) :: boolean
  def use_cache?(args) do
    case Keyword.get(args, :cache, false) do
      true -> true
      _ -> false
    end
  end

  @doc """
  Retrieves the filters from arguments and a new arguments set with the filters
  removed.
  """
  @spec get_filters(Keyword.t()) :: {list(any), Keyword.t()}
  def get_filters(args) do
    Filters.get_filters(args)
  end

  @doc "Reviews, adds, and cleans the arguments for use throughout ExDiceRoller."
  @spec sanitize(Keyword.t()) :: Keyword.t()
  def sanitize([]), do: []

  def sanitize(args) when is_list(args) do
    case args[:opts] do
      nil -> Keyword.put(args, :opts, [])
      val when is_list(val) -> args
      val -> Keyword.put(args, :opts, [val])
    end
  end

  @spec get_options(Keyword.t()) :: list(atom)
  def get_options(args) do
    Keyword.get(args, :opts, [])
  end

  @spec has_option?(Keyword.t(), atom) :: boolean
  def has_option?(args, key) do
    key in get_options(args)
  end

  @doc """
  Looks for and returns either the first option found from the provided list of
  atoms, or nil.
  """
  @spec find_first(Keyword.t(), list(atom)) :: atom | nil
  def find_first(args, keys) when is_list(keys) do
    args
    |> get_options()
    |> Enum.find(&(&1 in keys))
  end

  @spec get_var(Keyword.t(), atom) :: any
  def get_var(args, var_name) do
    Keyword.get(args, var_name)
  end
end
