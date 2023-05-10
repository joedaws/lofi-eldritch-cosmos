defmodule Eldritch.Being.Actions.Explore do
  @moduledoc """
  Visit previously unvisited locations
  """
  @enforce_keys [:priority, :preconditions]
  defstruct [:priority, :preconditions]

  def new(priority \\ 6, preconditions \\ {:none}) do
    %__MODULE__{priority: priority, preconditions: preconditions}
  end

  def preconditions_satisfied?(_being_observation) do
    # This means we allows allow a being to explore
    true
  end
end
