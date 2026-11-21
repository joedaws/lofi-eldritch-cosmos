defmodule LofiWeb.MeController do
  @moduledoc "Who is looking, and their being."
  use LofiWeb, :controller
  import LofiWeb.ApiHelpers

  # Also hands the page the CSRF token it needs for writes.
  def show(conn, _params) do
    user = current_user(conn)

    json(conn, %{
      "csrf_token" => get_csrf_token(),
      "user" =>
        user && %{"id" => user.id, "display_name" => user.display_name, "is_admin" => user.is_admin},
      "being" => user && my_being(user.id),
      "beckon_cooldown_ms" => Eldritch.Being.Owned.cooldown(),
      "max_cards" => Eldritch.Being.Deck.max_cards()
    })
  end

  @doc "The owner's own view of their being, with its whole deck"
  def my_being(user_id) do
    case Eldritch.Being.Owned.being_of(user_id) do
      nil ->
        nil

      vals ->
        cards =
          for card <- Eldritch.Being.Deck.cards(vals["deck"]) do
            Map.take(card, ~w(id front back box due_at awaiting streak recalls))
          end

        %{
          "id" => vals["id"],
          "name" => vals["name"],
          "temperament" => Eldritch.Being.Temperament.new(vals["temperament"] || %{}),
          "cards" => cards,
          "beckon_wait_ms" => Eldritch.Being.Owned.beckon_wait(vals)
        }
    end
  end
end
