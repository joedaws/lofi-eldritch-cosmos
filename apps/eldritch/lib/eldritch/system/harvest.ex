defmodule Eldritch.System.Harvest do
  require Logger

  def update_components(system) do
    Registry.dispatch(Cosmos.SystemRegistry, system, fn entries ->
      for {pid, _} <- entries, do: harvest(pid)
    end)
  end

  defp harvest(being_server) do
    # need to find the resource type
    {resource_type, resource_yield} =
      case Cosmos.Entity.Server.component(being_server, "at_node").value do
        nil ->
          {:nonode, 0}

        node_id ->
          node_server = Cosmos.Entity.Cache.server_process(node_id)
          resource_type = Cosmos.Entity.Server.component(node_server, "resource_type").value
          resource_yield = Cosmos.Entity.Server.component(node_server, "resource_yield").value
          {resource_type, resource_yield}
      end

    if resource_type != :nonode do
      GenServer.cast(
        being_server,
        {:update_component, "inventory",
         fn comp ->
           Map.update!(comp, :value, fn inventory_map ->
             Map.update!(inventory_map, "resources", fn resources_map ->
               Map.update(resources_map, resource_type, resource_yield, fn x ->
                 x + resource_yield
               end)
             end)
           end)
         end}
      )
    end
  end
end
