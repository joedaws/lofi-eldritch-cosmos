defmodule LofiWeb.BeingController do
  @moduledoc "Tending beings: answering whispers, beckoning, and the admin's tools."
  use LofiWeb, :controller
  import LofiWeb.ApiHelpers

  # Answer the card a being is whispering: {"id": ..., "answer": ...}
  # Owners answer their own beings; anyone signed in may answer the commons'.
  def recall(conn, params) do
    case Eldritch.Being.recall(params["id"], to_string(params["answer"] || ""), user_id(conn)) do
      {:ok, result} ->
        json(conn, result)

      {:error, :not_awaiting, due_in} ->
        conn
        |> put_status(:conflict)
        |> json(%{"error" => "the being is not whispering yet", "due_in_ms" => due_in})

      other ->
        domain_error(conn, other)
    end
  end

  # Draw a being to a place: {"id": ..., "node_id": ...}
  # Owners may beckon their own being now and then; the admin any being, any time.
  def beckon(conn, %{"id" => id, "node_id" => node_id}) do
    user = current_user(conn)

    result =
      with {:ok, entity} <- Eldritch.Being.fetch(id) do
        owner = Eldritch.Being.owner(Eldritch.Entities.to_values(entity))

        cond do
          user.is_admin and owner != user.id -> Eldritch.Being.beckon(id, node_id)
          owner == user.id -> Eldritch.Being.Owned.beckon(user.id, node_id)
          true -> {:error, :not_yours}
        end
      end

    case result do
      :ok -> json(conn, %{"message" => "the being heeds your call"})
      other -> domain_error(conn, other)
    end
  end

  def beckon(conn, _params), do: error(conn, :bad_request, "id and node_id are required")

  # Admin: summon a being of the commons
  def create(conn, params) do
    attributes =
      params
      |> Map.take(["name", "at_node"])
      |> Enum.reject(fn {_, v} -> v in [nil, ""] end)
      |> Map.new()

    attributes =
      case params["incantation"] do
        %{"front" => front} = card ->
          Map.put(attributes, "incantation", %{"front" => front, "back" => card["back"] || ""})

        _ ->
          attributes
      end

    being_id = Eldritch.Being.Builder.build({:new, :being, :standard}, attributes)
    name = Eldritch.Being.component(being_id, "name").value

    Eldritch.Chronicle.record(:summon, "#{name} is summoned by an unseen hand.", %{
      "beings" => [being_id],
      "node" => attributes["at_node"]
    })

    json(conn, %{"message" => "Created being", "being_id" => being_id})
  end

  # Admin: replace a being's deck with one card
  def incantation(conn, params) do
    case Eldritch.Being.set_incantation(params["id"], params["front"], params["back"]) do
      :ok -> json(conn, %{"message" => "the incantation is bound"})
      other -> domain_error(conn, other)
    end
  end
end
