defmodule Eldritch.Being.Actions do
  def move_to_node(being_id, node_id) do
    node_server = Cosmos.Entity.Cache.server_process(node_id)
    being_server = Cosmos.Entity.Cache.server_process(being_id)

    # remove being from current it's current node
    if Cosmos.Entity.Server.component(being_server, "at_node").value != nil do
      Cosmos.Entity.Server.update_component(node_server, "occupants", fn comp ->
        Map.update!(comp, :value, fn occupants -> MapSet.delete(occupants, being_id) end)
      end)
    end

    # occupants MapSet is updated
    Cosmos.Entity.Server.update_component(node_server, "occupants", fn comp ->
      Map.update!(comp, :value, fn occupants -> MapSet.put(occupants, being_id) end)
    end)

    # update the at_node component of a being
    Cosmos.Entity.Server.update_component(being_server, "at_node", fn comp ->
      Map.update!(comp, :value, fn _ -> node_id end)
    end)
  end
end
