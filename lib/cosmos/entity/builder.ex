defmodule Cosmos.Entity.Builder do
  @moduledoc """
  Used to format inital state of entities

  Not intended for use after the initialization of an entity
  """
  @starting_ichor 100
  @starting_orichalcum 100

  @doc """
  adds name, ichor, and orichalcum components to an empty entity

  attributes is a map with string keys which can be used to set
  the values of the starting components added to the entity
  """
  def build(:standard, attributes) do
    Cosmos.Entity.new()
    |> name(Map.get(attributes, "name", "jorsa"))
    |> ichor(Map.get(attributes, "ichor"))
    |> orichalcum(Map.get(attributes, "orichalcum"))
  end

  def name(entity, entity_name) do
    entity
    |> Cosmos.Entity.add_component(Cosmos.Entity.Component.new("name", :static, entity_name))
  end

  def ichor(entity, ichor_amount \\ @starting_ichor) do
    entity
    |> Cosmos.Entity.add_component(
      Cosmos.Entity.Component.new("ichor", :temporal_decay, ichor_amount)
    )
  end

  def orichalcum(entity, orichalcum_amount \\ @starting_orichalcum) do
    entity
    |> Cosmos.Entity.add_component(
      Cosmos.Entity.Component.new("orichalcum", :quantity, orichalcum_amount)
    )
  end
end
