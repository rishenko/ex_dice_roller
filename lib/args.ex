defmodule ExDiceRoller.Args do
  @moduledoc false

  alias ExDiceRoller.Filters

  @doc "True when caching is requested as `cache: true` or as `opts: [:cache]`."
  @spec use_cache?(Keyword.t()) :: boolean
  def use_cache?(args) do
    Keyword.get(args, :cache) == true or :cache in List.wrap(Keyword.get(args, :opts, []))
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

  @reserved [:opts | Filters.keys()]

  @doc """
  True when `args` is a keyword list without options or filters, such as
  `[x: 5]`. For those, `sanitize/1` and `get_filters/1` only add `opts: []`.
  """
  @spec plain?(list) :: boolean
  def plain?([]), do: true
  def plain?([{key, _} | _]) when key in @reserved, do: false
  def plain?([{key, _} | rest]) when is_atom(key), do: plain?(rest)
  def plain?(_), do: false

  @spec get_var(Keyword.t(), atom) :: any
  def get_var(args, var_name) do
    Keyword.get(args, var_name)
  end
end
