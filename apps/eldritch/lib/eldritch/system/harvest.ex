defmodule Eldritch.System.Harvest do
  @moduledoc """
  Living beings gather the resource of the node they occupy. Each
  harvest takes up to the node's `resource_yield` out of its `reserve`,
  so crowded places are quickly stripped bare. A being can carry at
  most #{40} units of resources in total.
  """
  require Logger
  alias Eldritch.Entities

  @carry_capacity 40

  def carry_capacity(), do: @carry_capacity

  def update_components(system) do
    for {pid, _being_id} <- Entities.members(system) do
      harvest(pid)
    end
  end

  defp harvest(being_server) do
    with vals when vals != nil <- Entities.values(being_server),
         true <- Entities.alive?(vals),
         node_id when node_id != nil <- vals["at_node"],
         node_server when is_pid(node_server) <- Cosmos.Entity.Cache.lookup(node_id) do
      resource_type = Cosmos.Entity.Server.value(node_server, "resource_type")
      carried = (get_in(vals, ["inventory", "resources"]) || %{}) |> Map.values() |> Enum.sum()

      resource_yield =
        node_server
        |> Cosmos.Entity.Server.value("resource_yield", 0)
        |> min(max(0, @carry_capacity - carried))

      gathered =
        case Cosmos.Entity.Server.get_and_update_component(node_server, "reserve", fn comp ->
               taken = min(resource_yield, comp.value["amount"])
               {taken, %{comp | value: Map.update!(comp.value, "amount", &(&1 - taken))}}
             end) do
          {:error, :no_component} -> resource_yield
          taken -> taken
        end

      if resource_type != nil and gathered > 0 do
        Eldritch.Being.Actions.give_resource(being_server, resource_type, gathered)
      end
    end
  end
end
