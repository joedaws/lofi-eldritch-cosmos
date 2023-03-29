defmodule Cosmos.Entity.Server do
  @moduledoc """
  Uses the transient restart option so that this server/worker
  will be restarted when there is an abnormal exit reason.
  This way we can retire servers when we don't need to update
  an entity or that entity has faded from existence.
  """
  use GenServer, restart: :transient
  require Logger

  def start_link(entity_id) do
    GenServer.start_link(__MODULE__, entity_id, name: via_tuple(entity_id))
  end

  def get(entity_server) do
    GenServer.call(entity_server, {:get})
  end

  def add_component(entity_server, component) do
    GenServer.cast(entity_server, {:add_component, component})
  end

  def delete_component(entity_server, component_id) do
    GenServer.cast(entity_server, {:delete_component, component_id})
  end

  def update_component(entity_server, component_name, updater_fn) do
    GenServer.cast(entity_server, {:update_component, component_name, updater_fn})
  end

  @impl true
  def init(entity_id) do
    Logger.info("starting entity server for entity #{inspect(entity_id)}")

    entity =
      case Cosmos.Database.get(entity_id) do
        nil ->
          Logger.info("entity #{entity_id} not found in database")
          Logger.info("Creating new entity")
          Cosmos.Entity.new()

        entity ->
          Logger.info("entity #{entity_id} found in database")
          Logger.info("registering entity to systems")
          register_all(entity_id, Cosmos.Entity.system_atoms(entity))
          entity
      end

    {:ok, {entity_id, entity}}
  end

  @impl true
  def handle_call({:get}, _from, {entity_id, entity}) do
    {:reply, entity, {entity_id, entity}}
  end

  @impl true
  def handle_cast({:add_component, component}, {entity_id, entity}) do
    new_entity = Cosmos.Entity.add_component(entity, component)
    Cosmos.Database.store(entity.id, new_entity)

    # register entity with system associated with new component's type
    register_to_system(entity_id, component.type)
    {:noreply, {entity_id, new_entity}}
  end

  @impl true
  def handle_cast({:delete_component, component_id}, {entity_id, entity}) do
    case Cosmos.Entity.delete_component(entity, component_id) do
      {entity, :not_found} ->
        {:noreply, {entity_id, entity}}

      {new_entity, removed_component} ->
        unregister_to_system(removed_component.type)
        Cosmos.Database.store(entity_id, new_entity)
        {:noreply, {entity_id, new_entity}}
    end
  end

  @impl true
  def handle_cast({:update_component, component_type, updater_fn}, {entity_id, entity}) do
    component_ids = for comp <- Cosmos.Entity.components(entity, component_type), do: comp.id

    new_entity =
      Enum.reduce(component_ids, entity, &Cosmos.Entity.update_component(&2, &1, updater_fn))

    {:noreply, {entity_id, new_entity}}
  end

  defp register_all(entity_id, system_atoms) do
    Enum.map(system_atoms, fn sys_atom -> register_to_system(entity_id, sys_atom) end)
  end

  defp register_to_system(entity_id, system_atom) do
    # only register to the system if not already present
    case Registry.match(Cosmos.SystemRegistry, system_atom, [entity_id]) do
      [] ->
        Logger.info("registering #{entity_id} to system #{system_atom}")
        Cosmos.SystemRegistry.register(entity_id, system_atom)

      [_] ->
        Logger.info("#{entity_id} already registered to system #{system_atom}")
    end
  end

  defp unregister_to_system(system_atom) do
    Cosmos.SystemRegistry.unregister(system_atom)
  end

  defp via_tuple(entity_id) do
    Cosmos.ProcessRegistry.via_tuple({__MODULE__, entity_id})
  end
end
