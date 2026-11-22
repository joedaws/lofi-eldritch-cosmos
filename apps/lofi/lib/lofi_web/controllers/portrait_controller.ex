defmodule LofiWeb.PortraitController do
  @moduledoc """
  Portraits of beings (`Lofi.Portrait`), public like the rest of the cosmos.

    * `GET /portraits/:id` draws a being as it is now (`?frame=0` leaves out
      the frame and name plate)
    * `GET /portraits/preview?name=…` draws the body a name would give, so a
      person can see who they are about to summon
    * `GET /portraits/:id/features` is what the portrait shows, with the
      prompt an image model would be given
  """
  use LofiWeb, :controller
  import LofiWeb.ApiHelpers

  def show(conn, %{"id" => id} = params) do
    case being_view(id) do
      nil -> conn |> put_status(:not_found) |> text("no such being")
      view -> view |> Lofi.Portrait.features() |> send_portrait(conn, params)
    end
  end

  def preview(conn, params) do
    name = params |> Map.get("name", "") |> String.slice(0, 32)
    name |> Lofi.Portrait.features() |> send_portrait(conn, params)
  end

  def features(conn, %{"id" => id}) do
    case being_view(id) do
      nil ->
        error(conn, :not_found, "no such being")

      view ->
        f = Lofi.Portrait.features(view)

        json(conn, %{
          "features" => f,
          "prompt" => Lofi.Portrait.prompt(f),
          "url" => Lofi.Portrait.url(view)
        })
    end
  end

  defp being_view(id) do
    case Eldritch.Being.fetch(id) do
      {:ok, entity} -> entity |> Eldritch.Entities.to_values() |> Eldritch.World.being_view(nil)
      :error -> nil
    end
  end

  defp send_portrait(features, conn, params) do
    etag = ~s("#{Lofi.Portrait.tag(features)}#{params["frame"]}")

    if etag in get_req_header(conn, "if-none-match") do
      send_resp(conn, 304, "")
    else
      {image, type} = Lofi.Portrait.render(features, frame: params["frame"] != "0")

      conn
      |> put_resp_content_type(type, nil)
      |> put_resp_header("etag", etag)
      # URLs carry ?v=<tag>, so a portrait at one URL never changes
      |> put_resp_header("cache-control", "public, max-age=86400")
      |> put_resp_header(
        "content-security-policy",
        "default-src 'none'; style-src 'unsafe-inline'"
      )
      |> send_resp(200, image)
    end
  end
end
