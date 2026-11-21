defmodule Cosmos.Entity.Server do
  @moduledoc """
  Uses the transient restart option so that this server/worker
  will be restarted when there is an abnormal exit reason.
  This way we can retire servers when we don't need to update
  an entity or that entity has faded from existence.

  Entity servers never call other entity servers. Logic that spans
  several entities lives in systems (or other callers), which keeps
  the process graph free of call cycles and therefore of deadlocks.
  """
  use GenServer, restart: :transient
  require Logger

  def start_link(entity_id) do
    GenServer.start_link(__MODULE__, entity_id, name: via_tuple(entity_id))
  end

  def get(entity_server) do
    GenServer.call(entity_server, {:get})
  end

  def component(entity_server, component_name) do
    GenServer.call(entity_server, {:component, component_name})
  end

  @doc """
  Returns the value of the named component or `default` when the
  entity has no such component.
  """
  def value(entity_server, component_name, default \\ nil) do
    case component(entity_server, component_name) do
      nil -> default
      comp -> comp.value
    end
  end

  def add_component(entity_server, %Cosmos.Entity.Component{} = component) do
    GenServer.cast(entity_server, {:add_component, component})
  end

  def add_component(_entity_server, invalid) do
    Logger.error("refusing to add invalid component #{inspect(invalid)}")
    {:error, invalid}
  end

  def delete_component(entity_server, component_id) do
    GenServer.cast(entity_server, {:delete_component, component_id})
  end

  def update_component(entity_server, component, updater_fn) do
    GenServer.cast(entity_server, {:update_component, component, updater_fn})
  end

  @doc """
  Atomically updates the component named `component_name`.

  `fun` receives the component and must return `{reply, new_component}`.
  `reply` is returned to the caller. When the component does not exist
  `{:error, :no_component}` is returned and nothing changes.

  This is used for transfers (e.g. one being gifting resources to
  another) where the caller needs to know exactly what happened.
  """
  def get_and_update_component(entity_server, component_name, fun) do
    GenServer.call(entity_server, {:get_and_update_component, component_name, fun})
  end

  @impl true
  def init(entity_id) do
    Logger.debug("starting entity server for entity #{inspect(entity_id)}")

    entity =
      case Cosmos.Database.get(entity_id) do
        nil ->
          Logger.debug("entity #{entity_id} not found in database, creating new entity")
          Cosmos.Entity.new_with_id(entity_id)

        entity ->
          Logger.debug("entity #{entity_id} found in database, registering to systems")
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
  def handle_call({:component, component_name}, _from, {entity_id, entity}) do
    {:reply, Cosmos.Entity.component(entity, component_name), {entity_id, entity}}
  end

  @impl true
  def handle_call({:get_and_update_component, component_name, fun}, _from, {entity_id, entity}) do
    case Cosmos.Entity.component(entity, component_name) do
      nil ->
        {:reply, {:error, :no_component}, {entity_id, entity}}

      comp ->
        {reply, new_comp} = fun.(comp)
        new_entity = Cosmos.Entity.update_component(entity, comp.id, fn _ -> new_comp end)
        Cosmos.Database.store(entity_id, new_entity)
        {:reply, reply, {entity_id, new_entity}}
    end
  end

  @impl true
  def handle_cast({:add_component, component}, {entity_id, entity}) do
    new_entity = Cosmos.Entity.add_component(entity, component)
    Cosmos.Database.store(entity_id, new_entity)

    # register entity with system associated with new component
    register_to_system(entity_id, component.system)
    {:noreply, {entity_id, new_entity}}
  end

  @impl true
  def handle_cast({:delete_component, component_id}, {entity_id, entity}) do
    case Cosmos.Entity.delete_component(entity, component_id) do
      {entity, :not_found} ->
        {:noreply, {entity_id, entity}}

      {new_entity, removed_component} ->
        # only leave the system when no other component still belongs to it
        if Cosmos.Entity.components(new_entity, removed_component.system) == [] do
          unregister_to_system(removed_component.system)
        end

        Cosmos.Database.store(entity_id, new_entity)
        {:noreply, {entity_id, new_entity}}
    end
  end

  @impl true
  def handle_cast({:update_component, component_system, updater_fn}, {entity_id, entity})
      when is_atom(component_system) do
    component_ids = for comp <- Cosmos.Entity.components(entity, component_system), do: comp.id

    new_entity =
      Enum.reduce(component_ids, entity, &Cosmos.Entity.update_component(&2, &1, updater_fn))

    Cosmos.Database.store(entity_id, new_entity)
    {:noreply, {entity_id, new_entity}}
  end

  @impl true
  def handle_cast({:update_component, component_name, updater_fn}, {entity_id, entity})
      when is_bitstring(component_name) do
    case Cosmos.Entity.component(entity, component_name) do
      nil ->
        Logger.warning("entity #{entity_id} has no component #{component_name} to update")
        {:noreply, {entity_id, entity}}

      comp ->
        new_entity = Cosmos.Entity.update_component(entity, comp.id, updater_fn)
        Cosmos.Database.store(entity_id, new_entity)
        {:noreply, {entity_id, new_entity}}
    end
  end

  defp register_all(entity_id, system_atoms) do
    Enum.each(system_atoms, fn sys_atom -> register_to_system(entity_id, sys_atom) end)
  end

  defp register_to_system(entity_id, system_atom) do
    # only register to the system if not already present
    case Registry.match(Cosmos.SystemRegistry, system_atom, [entity_id]) do
      [] ->
        Logger.debug("registering #{entity_id} to system #{inspect(system_atom)}")
        Cosmos.SystemRegistry.register(entity_id, system_atom)

      _ ->
        :ok
    end
  end

  defp unregister_to_system(system_atom) do
    Cosmos.SystemRegistry.unregister(system_atom)
  end

  defp via_tuple(entity_id) do
    Cosmos.ProcessRegistry.via_tuple({__MODULE__, entity_id})
  end
end
