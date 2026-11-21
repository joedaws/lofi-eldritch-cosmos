defmodule Eldritch do
  @moduledoc """
  Eldritch builds on the `Cosmos` ECS to describe a cosmos of beings
  roaming a landscape of nodes.

  Lofi should only talk to Eldritch, never to Cosmos directly, so that
  changes in how Cosmos stores data do not leak into the web layer.
  """

  @doc """
  Passes along the search filter from the the Lofi application to
  the Cosmos Application.

  filters
    * `"beings"` --> `%{"being_ids" => [...]}` all persisted and live beings
    * `"nodes"`  --> `%{"node_ids" => [...]}` all live nodes
  """
  def query("nodes") do
    %{"node_ids" => Eldritch.Entities.nodes() |> Enum.map(&elem(&1, 1))}
  end

  def query("beings") do
    %{"being_ids" => persisted} = Cosmos.query("beings")
    live = Eldritch.Being.all_ids()
    %{"being_ids" => Enum.uniq(persisted ++ live)}
  end

  def query(filter) do
    Cosmos.query(filter)
  end
end
