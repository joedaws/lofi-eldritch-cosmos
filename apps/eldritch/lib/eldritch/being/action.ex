defmodule Eldritch.Being.Action do
  @moduledoc """
  Behaviour for things a being may choose to do in a volition cycle.

  Every cycle the volition system offers the being all actions in order
  of descending `priority/0` and performs the first one whose
  preconditions are satisfied.

  The context passed to every callback holds:

    * `:id`, `:pid`, `:being` - the being's id, server and component values
    * `:graph` - `%{node_id => node_values}` of the whole landscape
    * `:kin_at` - `%{node_id => [being_values]}` of living beings per node
  """

  @type context :: map()

  @callback priority() :: number()
  @callback preconditions_satisfied?(context) :: boolean()
  @doc "Performs the action and returns `{intent, thought}`"
  @callback perform(context) :: {String.t(), String.t()}

  # helpers shared by actions

  def resources(ctx), do: get_in(ctx.being, ["inventory", "resources"]) || %{}
  def desire(ctx), do: get_in(ctx.being, ["volition", "desire"])
  def ichor(ctx), do: ctx.being["ichor"] || 0
  def here(ctx), do: Map.get(ctx.graph, ctx.being["at_node"])

  def neighbors(ctx, node_id \\ nil) do
    node_id = node_id || ctx.being["at_node"]

    case Map.get(ctx.graph, node_id) do
      nil -> []
      node -> node |> Map.get("neighbors", MapSet.new()) |> Enum.filter(&Map.has_key?(ctx.graph, &1))
    end
  end

  def reserve(node), do: get_in(node, ["reserve", "amount"]) || 0

  def node_name(ctx, node_id), do: get_in(ctx.graph, [node_id, "name"]) || "somewhere"

  def known_nodes(ctx), do: get_in(ctx.being, ["observations", "nodes"]) || %{}
  def visited(ctx), do: get_in(ctx.being, ["observations", "visited"]) || %{}

  def move(ctx, node_id), do: Eldritch.Being.Actions.move_to_node(ctx.id, node_id)

  def pretty(resource), do: resource |> to_string() |> String.replace("_", " ")

  @doc """
  First step on a shortest path from `from` to any node in `targets`
  (breadth first search over the landscape), or nil if unreachable.
  """
  def next_hop(ctx, from, targets) do
    targets = MapSet.new(targets)
    bfs(ctx, :queue.from_list([from]), %{from => nil}, targets, from)
  end

  defp bfs(ctx, queue, parents, targets, origin) do
    case :queue.out(queue) do
      {:empty, _} ->
        nil

      {{:value, node}, rest} ->
        if node != origin and MapSet.member?(targets, node) do
          first_step(parents, node, origin)
        else
          {queue, parents} =
            ctx
            |> neighbors(node)
            |> Enum.reject(&Map.has_key?(parents, &1))
            |> Enum.reduce({rest, parents}, fn n, {q, p} -> {:queue.in(n, q), Map.put(p, n, node)} end)

          bfs(ctx, queue, parents, targets, origin)
        end
    end
  end

  defp first_step(parents, node, origin) do
    case Map.get(parents, node) do
      ^origin -> node
      parent -> first_step(parents, parent, origin)
    end
  end
end
