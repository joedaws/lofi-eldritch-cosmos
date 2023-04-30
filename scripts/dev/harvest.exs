defmodule Dev.Harvest do
  @moduledoc """
  Useful for testing or observing the harvest system

  Creates a being and a node
  Moves being to node
  turns on the harvest system
  """
  being_id = Eldritch.Being.Builder.build({:new, :being, :standard})
  node_id = Eldritch.Node.Builder.build({:new, :node})

  Eldritch.Being.Actions.move_to_node(being_id, node_id)

  Cosmos.System.on(Eldritch.System.Harvest)
end
