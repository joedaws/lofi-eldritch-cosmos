defmodule Cosmos.Entity.Server do
  use GenServer, restart: :temporary
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

  @impl true
  def init(entity_id) do
    Logger.info("starting entity server for entity #{inspect(entity_id)}")
    {:ok, {entity_id, Cosmos.Database.get(entity_id) || Cosmos.Entity.new()}}
  end

  @impl true
  def handle_call({:get}, _from, {entity_id, entity}) do
    {:reply, entity, {entity_id, entity}}
  end

  @impl true
  def handle_cast({:add_component, component}, {entity_id, entity}) do
    new_entity = Cosmos.Entity.add_component(entity, component)
    Cosmos.Database.store(entity.id, new_entity)
    {:noreply, {entity_id, new_entity}}
  end

  @impl true
  def handle_cast({:delete_component, component_id}, {entity_id, entity}) do
    new_entity = Cosmos.Entity.delete_component(entity, component_id)
    Cosmos.Database.store(entity.id, new_entity)
    {:noreply, {entity_id, new_entity}}
  end

  defp via_tuple(entity_id) do
    Cosmos.ProcessRegistry.via_tuple({__MODULE__, entity_id})
  end
end
