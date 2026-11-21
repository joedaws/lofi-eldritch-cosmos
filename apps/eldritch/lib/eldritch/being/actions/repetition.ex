defmodule Eldritch.Being.Actions.Repetition do
  @moduledoc """
  The repetition compulsion: a being marked by a trauma (a bonded being
  fading) is drawn back to the place of the loss, the more strongly the
  more the Real weighs on it. Standing there works the symptom through,
  a little each time.
  """
  @behaviour Eldritch.Being.Action
  import Eldritch.Being.Action
  alias Eldritch.Lacan

  @impl true
  def priority(), do: 7.5

  @impl true
  def preconditions_satisfied?(ctx) do
    psyche = psyche(ctx)

    case psyche["symptom"] do
      %{"node" => node_id} when is_map_key(ctx.graph, node_id) ->
        :rand.uniform() < 1.5 * Lacan.weight(psyche, "real")

      _ ->
        false
    end
  end

  @impl true
  def perform(ctx) do
    %{"node" => node_id, "cause" => cause} = psyche(ctx)["symptom"]

    if ctx.being["at_node"] == node_id do
      psyche = Lacan.update(ctx.pid, &Lacan.work_through/1)

      if psyche && psyche["symptom"] == nil do
        Eldritch.Chronicle.record(
          :working_through,
          "#{ctx.being["name"]} has worked through its loss (#{cause}).",
          %{"beings" => [ctx.id], "node" => node_id}
        )
      end

      {"repeat", "I stand again in #{node_name(ctx, node_id)}, where #{cause}."}
    else
      case next_hop(ctx, ctx.being["at_node"], [node_id]) do
        nil ->
          {"repeat", "I cannot find my way back to #{node_name(ctx, node_id)}."}

        hop ->
          move(ctx, hop)
          {"repeat", "I am drawn back toward #{node_name(ctx, node_id)}. I do not know why."}
      end
    end
  end
end
