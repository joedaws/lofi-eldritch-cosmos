defmodule Cosmos.EntityServer do
  use GenServer

  @doc """
  While flushing out the functionality we naively have a single Entity Server.
  This will be changed in the future
  """
  def start() do
    GenServer.start_link(__MODULE__, :new_entity)
  end

  def start(entity_id) do
    GenServer.start_link(__MODULE__, entity_id)
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
  def init(:new_entity) do
    entity = Cosmos.Entity.new()
    {:ok, {entity.id, entity}}
  end

  @impl true
  def init(entity_id) do
    # :enoent means the file did not exist
    case Cosmos.Database.get(entity_id) do
      :enoent -> {:error, :enoent}
      entity -> {:ok, {entity_id, entity}}
    end
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
end
