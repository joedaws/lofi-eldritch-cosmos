defmodule Eldritch.Genesis do
  @moduledoc """
  Creating, loading and unmaking the cosmos.
  """
  require Logger

  @default_beings 12

  @doc """
  Seeds a new landscape and populates it with beings.

  Options: `:beings` (number of beings) plus any `Eldritch.Landscape.generate/1` option.
  Returns `%{"node_ids" => [...], "being_ids" => [...]}`.
  """
  def seed(opts \\ []) do
    node_ids = Eldritch.Landscape.generate(opts)
    being_count = Keyword.get(opts, :beings, @default_beings)

    being_ids =
      if node_ids == [] do
        []
      else
        for _ <- 1..being_count//1 do
          Eldritch.Being.Builder.build({:new, :being, :standard}, %{
            "at_node" => Enum.random(node_ids),
            "ichor" => Enum.random(70..130),
            "incantation" => Eldritch.KnowledgePack.random_incantation(),
            # a cosmos where everyone is a newborn is a strange cosmos
            "lineage" => %{"age" => Enum.random(0..400)}
          })
        end
      end

    Eldritch.Chronicle.record(
      :genesis,
      "A cosmos of #{length(node_ids)} places is dreamt into being, and #{length(being_ids)} beings awaken."
    )

    flush()
    %{"node_ids" => node_ids, "being_ids" => being_ids}
  end

  @doc """
  Starts an entity server for every persisted entity (so systems act on
  them) and upgrades entities saved by older versions.
  """
  def load_all() do
    %{"entity_ids" => ids} = Cosmos.query("entities")

    Enum.each(ids, fn id ->
      pid = Cosmos.Entity.Cache.server_process(id)
      entity = Cosmos.Entity.Server.get(pid)

      cond do
        Cosmos.Entity.component(entity, "is_node") != nil ->
          Eldritch.Node.Builder.ensure_standard(pid)

        Cosmos.Entity.component(entity, "is_being") != nil or
            Cosmos.Entity.component(entity, "ichor") != nil ->
          Eldritch.Being.Builder.ensure_standard(pid)

        true ->
          :ok
      end
    end)

    Logger.info("loaded #{length(ids)} entities from #{Cosmos.Database.path()}")
    length(ids)
  end

  @doc """
  Waits until every entity server has handled the messages sent to it so
  far and every resulting write has reached the disk.
  """
  def flush() do
    Enum.each(Cosmos.Entity.Cache.all_server_processes(), fn pid ->
      try do
        Cosmos.Entity.Server.get(pid)
      catch
        :exit, _ -> :ok
      end
    end)

    Cosmos.Database.sync()
  end

  @doc """
  Stops the simulation and destroys every entity (in memory and on disk).
  """
  def reset() do
    Eldritch.Simulation.stop()

    %{"entity_ids" => persisted} = Cosmos.query("entities")

    running =
      Cosmos.Entity.Cache.all_server_processes()
      |> Enum.flat_map(fn pid ->
        try do
          [Cosmos.Entity.Server.get(pid).id]
        catch
          :exit, _ -> []
        end
      end)

    ids = Enum.uniq(persisted ++ running)
    Enum.each(ids, &Cosmos.Entity.Cache.stop/1)
    Cosmos.Database.delete_all()
    Eldritch.Chronicle.clear()
    Eldritch.Chronicle.record(:cosmos, "The cosmos is unmade.")
    length(ids)
  end
end
