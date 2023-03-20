defmodule Cosmos.Entity.Builder do
  @moduledoc """
  Used to format inital state of entities

  Not intended for use after the initialization of an entity
  """
  @starting_ichor 100
  @starting_orichalcum 100

  @doc """
  adds name, ichor, and orichalcum components from scratch
  """
  def build({:new, :standard}, attributes) do
    new_entity = Cosmos.Entity.new()
    entity_id = new_entity.id
    Cosmos.Database.store(entity_id, new_entity)
    entity_server = Cosmos.Entity.Cache.server_process(entity_id)
    name(entity_server, Map.get(attributes, "name", "jorsa"))
    ichor(entity_server, Map.get(attributes, "ichor", @starting_ichor))
    orichalcum(entity_server, Map.get(attributes, "orichalcum", @starting_orichalcum))
  end

  @doc """
  adds name, ichor, and orichalcum components to an empty entity

  attributes is a map with string keys which can be used to set
  the values of the starting components added to the entity
  """
  def build({:existing, :standard}, entity_id, attributes) do
    entity_server = Cosmos.Entity.Cache.server_process(entity_id)
    name(entity_server, Map.get(attributes, "name", "jorsa"))
    ichor(entity_server, Map.get(attributes, "ichor", @starting_ichor))
    orichalcum(entity_server, Map.get(attributes, "orichalcum", @starting_orichalcum))
  end

  def name(entity_server, entity_name) do
    Cosmos.Entity.Server.add_component(
      entity_server,
      Cosmos.Entity.Component.new("name", :static, entity_name)
    )
  end

  def ichor(entity_server, ichor_amount) do
    Cosmos.Entity.Server.add_component(
      entity_server,
      Cosmos.Entity.Component.new("ichor", :temporal_decay, ichor_amount)
    )
  end

  def orichalcum(entity_server, orichalcum_amount) do
    Cosmos.Entity.Server.add_component(
      entity_server,
      Cosmos.Entity.Component.new("orichalcum", :quantity, orichalcum_amount)
    )
  end
end
