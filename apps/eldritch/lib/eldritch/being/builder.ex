defmodule Eldritch.Being.Builder do
  @moduledoc """
  Used to create new instances of being entities

  Not intended for use after the initialization of an entity
  """
  @starting_ichor 100
  @starting_orichalcum 100

  @doc """
  adds name, ichor, and orichalcum components from scratch

  returns the entity id of the newly created being
  """
  def build({:new, :being, :standard}, attributes \\ %{}) do
    new_entity = Cosmos.Entity.new()
    entity_id = new_entity.id
    Cosmos.Database.store(entity_id, new_entity)
    entity_server = Cosmos.Entity.Cache.server_process(entity_id)
    Eldritch.CommonComponent.name(entity_server, Map.get(attributes, "name", "jorsa"))
    ichor(entity_server, Map.get(attributes, "ichor", @starting_ichor))
    inventory(entity_server, Map.get(attributes, "orichalcum", @starting_orichalcum))
    at_node(entity_server, Map.get(attributes, "at_node", nil))
    entity_id
  end

  def ichor(entity_server, ichor_amount) do
    Cosmos.Entity.Server.add_component(
      entity_server,
      Cosmos.Entity.Component.new("ichor", Eldritch.System.TemporalDecay, ichor_amount)
    )
  end

  def is_being(entity_server) do
    Cosmos.Entity.Server.add_component(
      entity_server,
      Cosmos.Entity.Component.new("is_being", :is_being, true)
    )
  end

  def at_node(entity_server, node_id) do
    Cosmos.Entity.Server.add_component(
      entity_server,
      Cosmos.Entity.Component.new("at_node", :attribute, node_id)
    )

    Cosmos.Entity.Server.add_component(
      entity_server,
      Cosmos.Entity.Component.new("harvest", Eldritch.System.Harvest, true)
    )
  end

  def inventory(entity_server, orichalcum_amount) do
    Cosmos.Entity.Server.add_component(
      entity_server,
      Cosmos.Entity.Component.new("inventory", :inventory, %{
        "orichalcum" => orichalcum_amount,
        "resources" => %{}
      })
    )
  end
end
