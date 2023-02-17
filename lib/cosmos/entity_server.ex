defmodule Cosmos.EntityServer do
  use GenServer

  @doc """
  While flushing out the functionality we naively have a single Entity Server.
  This will be changed in the future
  """
  def start() do
    GenServer.start_link(__MODULE__, [])
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
  def init(_) do
    new_entity = Cosmos.Entity.new()
    {:ok, new_entity}
  end

  @impl true
  def handle_call({:get}, _from, entity) do
    {:reply, entity, entity}
  end

  @impl true
  def handle_cast({:add_component, component}, entity) do
    new_entity = Cosmos.Entity.add_component(entity, component)
    Cosmos.Database.store(entity.id, new_entity)
    {:noreply, new_entity}
  end

  @impl true
  def handle_cast({:delete_component, component_id}, entity) do
    new_entity = Cosmos.Entity.delete_component(entity, component_id)
    Cosmos.Database.store(entity.id, new_entity)
    {:noreply, new_entity}
  end
end
