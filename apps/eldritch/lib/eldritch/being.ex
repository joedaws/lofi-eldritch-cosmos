defmodule Eldritch.Being do
  @moduledoc """
  This module is responsible for high level interactions
  with generic beings.
  """

  @doc """
  Get a being given it's being/entity id.
  """
  def get(being_id) do
    Cosmos.Entity.Cache.server_process(being_id)
    |> Cosmos.Entity.Server.get()
  end

  def component(being_id, component_name) do
    Cosmos.Entity.Cache.server_process(being_id)
    |> Cosmos.Entity.Server.component(component_name)
  end

  def update(being_id, component, updater_function) do
    Cosmos.Entity.Cache.server_process(being_id)
    |> Cosmos.Entity.Server.update_component(component, updater_function)
  end
  
end
