defmodule Eldritch.Landscape do
  @moduledoc """
  Generates the landscape: a graph of nodes laid out on concentric
  rings. Nodes on a ring are connected to their ring neighbours and a
  random handful of edges join each ring to the next one out.

      q----w----e----r----t
      |    +              |
      |    i----o----p++++y
      |    |    |    |    |
      u++++f    b++++c    |
      |    |         |    |
      |    d----s----a++++l
      |                   |
      h---------j----k----z

  A single node at the centre (the heart of the cosmos) is joined to the
  innermost ring.
  """
  require Logger

  @default_rings [6, 10, 14]

  @doc """
  Options:
    * `:rings` - list with the number of nodes on each ring (inner first)
    * `:min_connections` / `:max_connections` - edges between adjacent rings
    * `:center` - whether to add a node at the centre (default true)

  Returns the list of created node ids.
  """
  def generate(opts \\ []) do
    rings = Keyword.get(opts, :rings, @default_rings)
    min_connections = Keyword.get(opts, :min_connections, 3)
    max_connections = Keyword.get(opts, :max_connections, 7)
    center? = Keyword.get(opts, :center, true)

    ring_count = length(rings)

    ring_nodes =
      rings
      |> Enum.with_index(1)
      |> Enum.map(fn {count, ring_idx} ->
        radius = ring_idx / ring_count
        offset = :rand.uniform() * 2 * :math.pi()

        for i <- 0..(count - 1) do
          angle = offset + 2 * :math.pi() * i / count
          id = build_node(%{"x" => radius * :math.cos(angle), "y" => radius * :math.sin(angle)})
          {id, angle}
        end
      end)

    # connect nodes around each ring
    for ring <- ring_nodes, length(ring) > 1 do
      ids = Enum.map(ring, &elem(&1, 0))

      ids
      |> Enum.zip(tl(ids) ++ [hd(ids)])
      |> Enum.uniq_by(fn {a, b} -> Enum.sort([a, b]) end)
      |> Enum.each(fn {a, b} -> Eldritch.Node.Actions.connect_nodes(a, b) end)
    end

    # connect adjacent rings, choosing angularly close partners
    ring_nodes
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.each(fn [inner, outer] ->
      count = Enum.random(min_connections..max_connections) |> min(length(inner))

      inner
      |> Enum.take_random(count)
      |> Enum.each(fn {inner_id, angle} ->
        {outer_id, _} = Enum.min_by(outer, fn {_, a} -> angular_distance(a, angle) end)
        Eldritch.Node.Actions.connect_nodes(inner_id, outer_id)
      end)
    end)

    center_ids =
      if center? and ring_nodes != [] do
        center_id =
          build_node(%{"x" => 0.0, "y" => 0.0}, %{"name" => "The Heart of the Cosmos"})

        ring_nodes
        |> hd()
        |> Enum.take_random(min(3, length(hd(ring_nodes))))
        |> Enum.each(fn {id, _} -> Eldritch.Node.Actions.connect_nodes(center_id, id) end)

        [center_id]
      else
        []
      end

    ids = center_ids ++ Enum.flat_map(ring_nodes, fn ring -> Enum.map(ring, &elem(&1, 0)) end)
    Logger.info("landscape generated with #{length(ids)} nodes")
    ids
  end

  defp build_node(position, attributes \\ %{}) do
    Eldritch.Node.Builder.build(
      {:new, :node},
      attributes
      |> Map.put("position", position)
      |> Map.put_new_lazy("name", &Eldritch.Node.NameGenerator.next/0)
    )
  end

  defp angular_distance(a, b) do
    d = abs(:math.fmod(a - b, 2 * :math.pi()))
    min(d, 2 * :math.pi() - d)
  end
end
