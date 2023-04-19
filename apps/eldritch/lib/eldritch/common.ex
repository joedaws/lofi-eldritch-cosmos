defmodule Eldritch.Common do
  @moduledoc """
  Defines function to create common components that many
  different kinds of entities may use
  """

  def name(entity_server, entity_name) do
    Cosmos.Entity.Server.add_component(
      entity_server,
      Cosmos.Entity.Component.new("name", :attribute, entity_name)
    )
  end
end
