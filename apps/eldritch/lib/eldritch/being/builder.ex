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
  def build({:new, :being, :standard}, attributes) do
    new_entity = Cosmos.Entity.new()
    entity_id = new_entity.id
    Cosmos.Database.store(entity_id, new_entity)
    entity_server = Cosmos.Entity.Cache.server_process(entity_id)
    Eldritch.CommonComponent.name(entity_server, Map.get(attributes, "name", "jorsa"))
    ichor(entity_server, Map.get(attributes, "ichor", @starting_ichor))
    inventory(entity_server, Map.get(attributes, "orichalcum", @starting_orichalcum))
    entity_id
  end

  @doc """
  adds name, ichor, and orichalcum components to an empty entity

  attributes is a map with string keys which can be used to set
  the values of the starting components added to the entity
  """
  def build({:existing, :being, :standard}, entity_id, attributes) do
    entity_server = Cosmos.Entity.Cache.server_process(entity_id)
    Eldritch.CommonComponent.name(entity_server, Map.get(attributes, "name", "jorsa"))
    ichor(entity_server, Map.get(attributes, "ichor", @starting_ichor))
    inventory(entity_server, Map.get(attributes, "orichalcum", @starting_orichalcum))
  end

  def ichor(entity_server, ichor_amount) do
    Cosmos.Entity.Server.add_component(
      entity_server,
      Cosmos.Entity.Component.new("ichor", Eldritch.System.TemporalDecay, ichor_amount)
    )
  end

  def is_node(entity_server) do
    Cosmos.Entity.Server.add_component(
      entity_server,
      Cosmos.Entity.Component.new("is_being", :is_being, true)
    )
  end

  def inventory(entity_server, orichalcum_amount) do
    Cosmos.Entity.Server.add_component(
      entity_server,
      Cosmos.Entity.Component.new("inventory", :inventory, %{"orichalcum" => orichalcum_amount})
    )
  end
end
