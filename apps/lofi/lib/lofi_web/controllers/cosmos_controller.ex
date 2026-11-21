defmodule LofiWeb.CosmosController do
  @moduledoc "Watching the cosmos (anyone) and running it (admin)."
  use LofiWeb, :controller
  import LofiWeb.ApiHelpers

  def ping(conn, _params) do
    json(conn, %{"message" => "You have reached the lofi-eldritch-cosmos"})
  end

  # The whole cosmos as the viewer may see it, plus chronicle events after `since`
  def world(conn, params) do
    world =
      Eldritch.World.snapshot(since: parse_int(params["since"], 0), viewer: user_id(conn))

    json(conn, with_owner_names(world))
  end

  def beings(conn, _params), do: json(conn, Eldritch.query("beings"))
  def nodes(conn, _params), do: json(conn, Eldritch.query("nodes"))

  def being(conn, params) do
    case Eldritch.Being.fetch(params["id"]) do
      {:ok, entity} ->
        # the raw entity, minus the parts that belong to its owner alone
        entity = Eldritch.Entities.to_json(entity)

        components =
          Map.new(entity["components"], fn
            {k, %{"name" => "deck"} = c} -> {k, %{c | "value" => %{"cards" => length(c["value"]["cards"])}}}
            other -> other
          end)

        json(conn, %{entity | "components" => components})

      :error ->
        error(conn, :not_found, "no such being")
    end
  end

  def simulation(conn, _params), do: json(conn, Eldritch.Simulation.status())

  def start(conn, _params) do
    Eldritch.Simulation.start()
    json(conn, Eldritch.Simulation.status())
  end

  def stop(conn, _params) do
    Eldritch.Simulation.stop()
    json(conn, Eldritch.Simulation.status())
  end

  # {"tick_ms": 500}
  def speed(conn, params) do
    case parse_int(params["tick_ms"], nil) do
      nil ->
        error(conn, :bad_request, "tick_ms must be an integer")

      tick_ms ->
        Eldritch.Simulation.set_tick_ms(tick_ms)
        json(conn, Eldritch.Simulation.status())
    end
  end

  # {"beings": 12, "rings": [6, 10, 14], "reset": true}
  def seed(conn, params) do
    if params["reset"] in [true, "true"], do: Eldritch.Genesis.reset()

    rings =
      case params["rings"] do
        rings when is_list(rings) and rings != [] ->
          rings |> Enum.map(&(parse_int(&1, 6) |> max(1) |> min(40))) |> Enum.take(6)

        _ ->
          [6, 10, 14]
      end

    result =
      Eldritch.Genesis.seed(
        beings: parse_int(params["beings"], 12) |> max(0) |> min(60),
        rings: rings
      )

    json(conn, %{"nodes" => length(result["node_ids"]), "beings" => length(result["being_ids"])})
  end

  def reset(conn, _params) do
    json(conn, %{"removed" => Eldritch.Genesis.reset()})
  end

  # Eldritch knows owners only by id; people see display names
  defp with_owner_names(world) do
    ids = world["beings"] |> Enum.map(& &1["owner_id"]) |> Enum.reject(&is_nil/1) |> Enum.uniq()
    names = Map.new(Lofi.Accounts.get_users(ids), &{&1.id, &1.display_name})

    beings =
      Enum.map(world["beings"], fn b ->
        b |> Map.put("owner", names[b["owner_id"]]) |> Map.delete("owner_id")
      end)

    %{world | "beings" => beings}
  end
end
