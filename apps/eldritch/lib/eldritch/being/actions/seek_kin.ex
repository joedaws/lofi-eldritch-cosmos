defmodule Eldritch.Being.Actions.SeekKin do
  @moduledoc "A being is drawn to a nearby being it has bonded with."
  @behaviour Eldritch.Being.Action
  import Eldritch.Being.Action

  @fondness 10
  @pull 0.35

  @impl true
  def priority(), do: 5

  @impl true
  def preconditions_satisfied?(ctx), do: kin_nearby(ctx) != [] and :rand.uniform() < @pull

  @impl true
  def perform(ctx) do
    {node_id, kin} = Enum.random(kin_nearby(ctx))
    move(ctx, node_id)
    {"seek kin", "I go to join #{kin["name"]} at #{node_name(ctx, node_id)}."}
  end

  defp kin_nearby(ctx) do
    bonds = ctx.being["bonds"] || %{}

    for node_id <- neighbors(ctx),
        kin <- Map.get(ctx.kin_at, node_id, []),
        Map.get(bonds, kin["id"], 0) >= @fondness,
        do: {node_id, kin}
  end
end
