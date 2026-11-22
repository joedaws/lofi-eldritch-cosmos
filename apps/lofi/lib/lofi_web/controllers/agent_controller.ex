defmodule LofiWeb.AgentController do
  @moduledoc """
  The plain JSON face of `Lofi.Agent`, for agents that do not speak MCP.
  Every route needs `Authorization: Bearer lofi_agent_…`.
  """
  use LofiWeb, :controller

  def being(conn, _), do: run(conn, "my_being")
  def cards(conn, _), do: run(conn, "my_cards")
  def whispering(conn, _), do: run(conn, "whispering_now")
  def accuracy(conn, _), do: run(conn, "card_accuracy")
  def history(conn, params), do: run(conn, "recent_history", params)
  def events(conn, params), do: run(conn, "what_befell_my_being", params)
  def overview(conn, _), do: run(conn, "cosmos_overview")
  def explain(conn, params), do: run(conn, "explain", params)
  def add_card(conn, params), do: run(conn, "add_card", params, :created)
  def rewrite_card(conn, %{"card_id" => _} = params), do: run(conn, "rewrite_card", params)
  def burn_card(conn, %{"card_id" => _} = params), do: run(conn, "burn_card", params)

  defp run(conn, tool, params \\ %{}, status \\ :ok) do
    %{agent_user: user, agent_token: token} = conn.assigns

    case Lofi.Agent.call(user, tool, params, "agent: #{token.name}") do
      {:ok, result} -> conn |> put_status(status) |> json(%{"result" => result})
      {:error, message} -> conn |> put_status(:unprocessable_entity) |> json(%{"error" => message})
    end
  end
end
