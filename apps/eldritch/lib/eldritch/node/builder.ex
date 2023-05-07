defmodule Eldritch.Node.Builder do
  @moduledoc """
  Used to create new instances of node entities
  """
  require Logger

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
