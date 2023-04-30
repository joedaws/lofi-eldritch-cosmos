defmodule HarvestDev do
  being_id = Eldritch.Being.Builder.build({:new, :being, :standard}, %{})
  being_server = Cosmos.Entity.Cache.server_process(being_id)
  node_id = Eldritch.Node.Builder.build({:new, :node}, %{})
  node_server = Cosmos.Entity.Cache.server_process(node_id)

  Eldritch.Being.Actions.move_to_node(being_id, node_id)

  Cosmos.System.on(Eldritch.System.TemporalDecay)
  Cosmos.System.on(Eldritch.System.Harvest)
end
