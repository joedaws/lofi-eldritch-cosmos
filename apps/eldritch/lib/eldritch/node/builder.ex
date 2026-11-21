defmodule Eldritch.Node.Builder do
  @moduledoc """
  Used to create new instances of node entities
  """
  require Logger

  @default_reserve 60
  @max_reserve 120

  @doc """
  adds the name to a node entity

  returns the entity id of the newly created being
  """
  def build({:new, :node}, attributes \\ %{}) do
    {node_server, node_id} = get_new_node()

    Eldritch.CommonComponent.name(
      node_server,
      Map.get(attributes, "name", Eldritch.Node.Name.generate_name())
    )

    is_node(node_server)

    resource(
      node_server,
      Map.get(attributes, "resource_type", Eldritch.Node.Resource.get_random_resource_type()),
      Map.get(attributes, "resource_yield", Enum.random(1..10))
    )

    occupants(node_server)
    neighbors(node_server)
    reserve(node_server, Map.get(attributes, "reserve", @default_reserve))
    position(node_server, Map.get(attributes, "position"))

    node_id
  end

  def is_node(entity_server) do
    Cosmos.Entity.Server.add_component(
      entity_server,
      Cosmos.Entity.Component.new("is_node", :is_node, true)
    )
  end

  def resource(entity_server, resource_type, resource_yield) do
    if Eldritch.Node.Resource.valid_resource_type?(resource_type) and
         Eldritch.Node.Resource.valid_resource_yield?(resource_yield) do
      Cosmos.Entity.Server.add_component(
        entity_server,
        Cosmos.Entity.Component.new("resource_type", :attribute, resource_type)
      )

      Cosmos.Entity.Server.add_component(
        entity_server,
        Cosmos.Entity.Component.new("resource_yield", :attribute, resource_yield)
      )
    else
      Logger.error("Invalid resource_yield or resource_type in builder for node")
    end
  end

  @doc """
  How much of the node's resource can still be harvested.
  Harvesting depletes it, the regrowth system slowly replenishes it.
  """
  def reserve(entity_server, amount) do
    Cosmos.Entity.Server.add_component(
      entity_server,
      Cosmos.Entity.Component.new("reserve", Eldritch.System.Regrowth, %{
        "amount" => amount,
        "max" => @max_reserve
      })
    )
  end

  @doc """
  `%{"x" => x, "y" => y}` in [-1, 1] used to draw the landscape (or nil)
  """
  def position(entity_server, position) do
    Cosmos.Entity.Server.add_component(
      entity_server,
      Cosmos.Entity.Component.new("position", :attribute, position)
    )
  end

  @doc """
  Adds components missing from nodes persisted by an earlier version
  """
  def ensure_standard(entity_server) do
    entity = Cosmos.Entity.Server.get(entity_server)

    if Cosmos.Entity.component(entity, "reserve") == nil,
      do: reserve(entity_server, @default_reserve)

    if Cosmos.Entity.component(entity, "position") == nil, do: position(entity_server, nil)
    :ok
  end

  def occupants(entity_server) do
    Cosmos.Entity.Server.add_component(
      entity_server,
      Cosmos.Entity.Component.new("occupants", :attribute, MapSet.new())
    )
  end

  def neighbors(entity_server) do
    Cosmos.Entity.Server.add_component(
      entity_server,
      Cosmos.Entity.Component.new("neighbors", :attribute, MapSet.new())
    )
  end

  defp get_new_node() do
    new_node = Cosmos.Entity.new()
    node_id = new_node.id
    Cosmos.Database.store(node_id, new_node)
    node_server = Cosmos.Entity.Cache.server_process(node_id)
    {node_server, node_id}
  end
end
