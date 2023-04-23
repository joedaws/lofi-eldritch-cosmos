defmodule Eldritch.Node.Builder do
  @moduledoc """
  Used to create new instances of node entities
  """
  @default_node_name "hill side tavern"

  @doc """
  adds the name to a node entity

  returns the entity id of the newly created being
  """
  def build({:new, :node}, attributes) do
    new_node = Cosmos.Entity.new()
    node_id = new_node.id
    Cosmos.Database.store(node_id, new_node)
    entity_server = Cosmos.Entity.Cache.server_process(node_id)
    Eldritch.CommonComponent.name(entity_server, Map.get(attributes, "name", @default_node_name))
    is_node(entity_server)
    node_id
  end

  def is_node(entity_server) do
    Cosmos.Entity.Server.add_component(
      entity_server,
      Cosmos.Entity.Component.new("is_node", :attribute, true)
    )
  end
end
