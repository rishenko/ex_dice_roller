defmodule ExDiceRoller.Application do
  @moduledoc """
  Starts ExDiceRoller's supervision tree:

  * `ExDiceRoller.CacheSupervisor`, a `DynamicSupervisor` for caches started
  with `ExDiceRoller.start_cache/1`
  * the default cache, named by the `:cache_table` config (default
  `ExDiceRoller.Cache`)

  Each cache's ETS table is owned by a supervised `ExDiceRoller.Cache`
  process, so it outlives the process that first used it.
  """

  use Application

  @cache_table Application.compile_env(:ex_dice_roller, :cache_table, ExDiceRoller.Cache)

  @impl true
  def start(_type, _args) do
    children = [
      {DynamicSupervisor, name: ExDiceRoller.CacheSupervisor, strategy: :one_for_one},
      {ExDiceRoller.Cache, name: @cache_table}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: ExDiceRoller.Supervisor)
  end
end
