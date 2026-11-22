defmodule LofiWeb.WorldView do
  @moduledoc """
  The world as one person may see it.

  `Eldritch.World.snapshot/1` knows owners only by id. Here owners get their
  display names, and a snapshot taken for nobody in particular (the one the
  broadcaster pushes to every viewer) is personalised for each viewer: which
  being is theirs, which whispers they may answer, and the words of their own
  cards. Other people's cards never leave the server.
  """

  @doc "Display names for owner ids; keeps `owner_id` for `personalise/2`"
  def name_owners(world) do
    ids = world["beings"] |> Enum.map(& &1["owner_id"]) |> Enum.reject(&is_nil/1) |> Enum.uniq()
    names = Map.new(Lofi.Accounts.get_users(ids), &{&1.id, &1.display_name})
    %{world | "beings" => Enum.map(world["beings"], &Map.put(&1, "owner", names[&1["owner_id"]]))}
  end

  @doc """
  Tailors a named, viewer-less snapshot for `user_id` (nil when anonymous)
  and removes the owner ids.
  """
  def personalise(world, user_id) do
    mine = user_id && Eldritch.Being.Owned.being_of(user_id)

    beings =
      Enum.map(world["beings"], fn b ->
        cond do
          mine && b["id"] == mine["id"] ->
            # the viewer's own being, seen with their eyes (their card's words)
            mine |> Eldritch.World.being_view(user_id) |> Map.put("owner", b["owner"])

          true ->
            Map.merge(b, %{
              "mine" => false,
              "can_answer" => user_id != nil and b["owner_id"] == nil
            })
        end
        |> Map.delete("owner_id")
      end)

    %{world | "beings" => beings}
  end

  @doc "A snapshot for one viewer (used by GET /world and on joining the channel)"
  def for_viewer(user_id, opts \\ []) do
    opts
    |> Keyword.put(:viewer, nil)
    |> Eldritch.World.snapshot()
    |> name_owners()
    |> personalise(user_id)
  end
end
