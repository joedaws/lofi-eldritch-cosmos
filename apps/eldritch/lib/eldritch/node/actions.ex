defmodule Eldritch.Node.Actions do
  def connect_nodes(node_id_1, node_id_2) do
    node_server_1 = Cosmos.Entity.Cache.server_process(node_id_1)
    node_server_2 = Cosmos.Entity.Cache.server_process(node_id_2)

    # all edges are bi-directional
    Cosmos.Entity.Server.update_component(node_server_1, "neighbors", fn comp ->
      Map.update!(comp, :value, fn neighbors -> MapSet.put(neighbors, node_id_2) end)
    end)

    Cosmos.Entity.Server.update_component(node_server_2, "neighbors", fn comp ->
      Map.update!(comp, :value, fn neighbors -> MapSet.put(neighbors, node_id_1) end)
    end)
  end
end
