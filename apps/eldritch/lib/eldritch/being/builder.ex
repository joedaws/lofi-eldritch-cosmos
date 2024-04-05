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
    # a new being does not start with observations, so no override is provided
    observations(entity_server)
    incantation(entity_server)
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

  def observations(entity_server) do
    Cosmos.Entity.Server.add_component(
      entity_server,
      Cosmos.Entity.Component.new("observations", Eldritch.System.Observation, %{
        "nodes_and_resources" => MapSet.new()
      })
    )
  end

  @doc """
  an incantation is like a flash card, it has a front and a back.

  The user can chose wether to fill in the front or back.

  A single sided flash card is a "declarative Incantation"
  A two-sided flash card is a "flash Incantation"
  """
  def incantation(entity_server) do
    # initialize front
    Cosmos.Entity.Server.add_component(
      entity_server,
      Cosmos.Entity.Component.new("Incantation", Eldritch.System.Remind, %{
        "front" => "Breath life into the being with this Incantation",
        "back" => "Secrets can strengthen life force"
      })
    )
  end
end
