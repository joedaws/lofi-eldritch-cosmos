defmodule LofiWeb.MyBeingController do
  @moduledoc "A person summoning and shaping their one being."
  use LofiWeb, :controller
  import LofiWeb.ApiHelpers
  alias Eldritch.Being.Owned

  # {"name": ..., "at_node": ..., "temperament": {...}, "cards": [{"front", "back"}]}
  def create(conn, params) do
    user = current_user(conn)
    attrs = params |> Map.take(~w(name at_node temperament cards)) |> Map.put("owner_name", user.display_name)

    case Owned.summon(user.id, attrs) do
      {:ok, id} -> conn |> put_status(:created) |> json(%{"being_id" => id, "being" => LofiWeb.MeController.my_being(user.id)})
      other -> domain_error(conn, other)
    end
  end

  # {"generosity": 0..100, "wanderlust": ..., "sociability": ..., "conformity": ...}
  def temperament(conn, params) do
    case Owned.set_temperament(user_id(conn), Map.take(params, Eldritch.Being.Temperament.traits())) do
      {:ok, temperament} -> json(conn, %{"temperament" => temperament})
      other -> domain_error(conn, other)
    end
  end

  def add_card(conn, params) do
    case Owned.add_card(user_id(conn), params["front"], params["back"]) do
      {:ok, card} -> conn |> put_status(:created) |> json(%{"card" => card})
      other -> domain_error(conn, other)
    end
  end

  def update_card(conn, %{"card_id" => card_id} = params) do
    case Owned.update_card(user_id(conn), card_id, params["front"], params["back"]) do
      {:ok, _deck} -> json(conn, %{"message" => "the card is rewritten"})
      other -> domain_error(conn, other)
    end
  end

  def delete_card(conn, %{"card_id" => card_id}) do
    case Owned.delete_card(user_id(conn), card_id) do
      {:ok, _deck} -> json(conn, %{"message" => "the card is burned"})
      other -> domain_error(conn, other)
    end
  end
end
