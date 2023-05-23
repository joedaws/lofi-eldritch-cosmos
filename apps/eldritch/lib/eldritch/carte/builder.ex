defmodule Eldritch.Carte.Builder do
  @moduledoc """
  Used to create new instances of carte (flash cards) entities
  """
  require Logger

  @doc """
  adds components to a new carte entity

  returns the entity id
  """
  def build({:new, :carte}, query, response) do
    {carte_server, carte_id} = get_new_carte()

    is_carte(carte_server)
    flashcard(entity_server, query, response)

    carte_id
  end

  def is_carte(entity_server) do
    Cosmos.Entity.Server.add_component(
      entity_server,
      Cosmos.Entity.Component.new("is_carte", :is_carte, true)
    )
  end

  def flashcard(entity_server, query, response) do
    Cosmos.Entity.Server.add_component(
      entity_server,
      Cosmos.Entity.Component.new("query", :attribute, query)
    )
    Cosmos.Entity.Server.add_component(
      entity_server,
      Cosmos.Entity.Component.new("answer", :attribute, answer)
    )
  end

  defp get_new_carte() do
    new_carte = Cosmos.Entity.new()
    carte_id = new_carte.id
    Cosmos.Database.store(carte_id, new_carte)
    carte_server = Cosmos.Entity.Cache.server_process(carte_id)
    {carte_server, carte_id}
  end
end
