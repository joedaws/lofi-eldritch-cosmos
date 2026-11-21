defmodule Eldritch.System.Observation do
  @moduledoc """
  Beings remember the nodes they stand in and glimpse the resources
  of the neighbouring nodes.
  """
  require Logger
  alias Eldritch.Entities

  def update_components(system) do
    for {pid, _} <- Entities.members(system), do: make_observation(pid)
  end

  defp make_observation(being_server) do
    with vals when vals != nil <- Entities.values(being_server),
         true <- Entities.alive?(vals),
         node_id when node_id != nil <- vals["at_node"],
         node_server when is_pid(node_server) <- Cosmos.Entity.Cache.lookup(node_id) do
      resource_type = Cosmos.Entity.Server.value(node_server, "resource_type")
      neighbors = Cosmos.Entity.Server.value(node_server, "neighbors", MapSet.new())

      glimpsed =
        for neighbor_id <- neighbors,
            pid <- List.wrap(Cosmos.Entity.Cache.lookup(neighbor_id)),
            into: %{},
            do: {neighbor_id, Cosmos.Entity.Server.value(pid, "resource_type")}

      Cosmos.Entity.Server.update_component(being_server, "observations", fn comp ->
        Map.update!(comp, :value, fn observations ->
          observations
          |> Map.update("nodes", %{node_id => resource_type}, fn nodes ->
            nodes |> Map.merge(glimpsed) |> Map.put(node_id, resource_type)
          end)
          |> Map.update("visited", %{node_id => true}, &Map.put(&1, node_id, true))
        end)
      end)
    end
  end
end
