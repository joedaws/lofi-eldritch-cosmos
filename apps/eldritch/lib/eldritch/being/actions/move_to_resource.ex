defmodule Eldritch.Being.Actions.MoveToResource do
  @moduledoc """
  Creates an action queue to move a being to a node with a desired resource
  """
  @enforce_keys [:priority, :preconditions]
  defstruct [:priority, :preconditions]

  def preconditions_satisfied?(being_observations, desired_resource) do
    nodes = Map.get(being_observations, "visited_nodes")
    node = Enum.find(nodes, nil, fn x -> x.resource == desired_resource end)
    node != nil
  end

  @doc """
  This action can only be performed if the being knows of a
  node with the desired resource.
  """
  def perform(being_id, being_observations, desired_resource) do
    nodes = Map.get(being_observations, "visited_nodes")
    node_id = Enum.find(nodes, nil, fn x -> x.resource == desired_resource end).node_id
    Eldritch.Being.Actions.move_to_node(being_id, node_id)
  end
end
