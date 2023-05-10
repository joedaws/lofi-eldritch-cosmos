defmodule Eldritch.System.Observation do
  require Logger

  def update_components(system) do
    Registry.dispatch(Cosmos.SystemRegistry, system, fn entries ->
      for {pid, _} <- entries, do: make_observation(pid)
    end)
  end

  defp make_observation(being_server) do
    # observe current node and update resource type
    {node_id, resource_type} =
      case Cosmos.Entity.Server.component(being_server, "at_node").value do
        nil ->
          {:nonode, :no_resource_type}

        node_id ->
          node_server = Cosmos.Entity.Cache.server_process(node_id)
          resource_type = Cosmos.Entity.Server.component(node_server, "resource_type").value
          {node_id, resource_type}
      end

    if node_id != :nonode do
      GenServer.cast(
        being_server,
        {:update_component, "observations",
         fn comp ->
           Map.update!(comp, :value, fn observations_map ->
             Map.update!(observations_map, "nodes_and_resources", fn nodes_and_resources_mapset ->
               MapSet.put(nodes_and_resources_mapset, {node_id, resource_type})
             end)
           end)
         end}
      )
    end
  end
end
