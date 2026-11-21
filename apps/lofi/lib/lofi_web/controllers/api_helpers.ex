defmodule LofiWeb.ApiHelpers do
  @moduledoc "Shared helpers for the JSON controllers."
  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  def current_user(conn) do
    case conn.assigns[:current_scope] do
      %{user: user} -> user
      _ -> nil
    end
  end

  def user_id(conn), do: current_user(conn) && current_user(conn).id

  def error(conn, status, message) do
    conn |> put_status(status) |> json(%{"error" => message})
  end

  @messages %{
    already_has_being: "you already have a being",
    no_being: "you have no being yet",
    no_places: "the cosmos has no places yet",
    unknown_node: "no such place",
    unknown_being: "no such being",
    name_too_long: "names are at most 32 characters",
    bad_name: "that name cannot be spoken",
    bad_cards: "cards need a front (and optionally a back)",
    empty_front: "a card needs a front",
    too_long: "card sides are at most 200 characters",
    deck_full: "a deck holds at most 30 cards",
    no_card: "no such card",
    not_yours: "that being is not yours to tend",
    faded: "a faded being cannot be beckoned"
  }

  @doc "Renders an Eldritch error tuple as JSON"
  def domain_error(conn, {:error, {:cooldown, ms}}) do
    conn
    |> put_status(:too_many_requests)
    |> json(%{"error" => "your being will heed you again later", "retry_in_ms" => ms})
  end

  def domain_error(conn, {:error, reason}) when is_map_key(@messages, reason) do
    status =
      case reason do
        :not_yours -> :forbidden
        :no_being -> :not_found
        :no_card -> :not_found
        :unknown_being -> :not_found
        _ -> :unprocessable_entity
      end

    error(conn, status, @messages[reason])
  end

  def domain_error(conn, :error), do: error(conn, :not_found, "no such being")
  def domain_error(conn, other), do: error(conn, :unprocessable_entity, inspect(other))

  def parse_int(value, _default) when is_integer(value), do: value

  def parse_int(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> default
    end
  end

  def parse_int(_, default), do: default
end
