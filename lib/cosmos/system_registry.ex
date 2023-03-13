defmodule Cosmos.SystemRegistry do
  require Logger

  def start_link do
    Logger.info("Starting System Registry")

    Registry.start_link(
      keys: :duplicate,
      name: __MODULE__,
      partitions: System.schedulers_online()
    )
  end

  def register(entity_id, system_atom) when is_atom(system_atom) do
    Registry.register(__MODULE__, system_atom, [entity_id])
  end

  def unregister(system_atom) when is_atom(system_atom) do
    Registry.unregister(__MODULE__, system_atom)
  end

  def via_tuple(key) do
    {:via, Registry, {__MODULE__, key}}
  end

  def child_spec(_) do
    Supervisor.child_spec(
      Registry,
      id: __MODULE__,
      start: {__MODULE__, :start_link, []}
    )
  end
end
