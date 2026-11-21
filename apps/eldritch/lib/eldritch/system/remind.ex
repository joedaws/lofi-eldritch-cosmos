defmodule Eldritch.System.Remind do
  @moduledoc """
  Spaced repetition: when a card in a being's deck comes due, the being
  begins to whisper it and waits for someone to answer
  (see `Eldritch.Being.recall/3`). A being whispers one card at a time.
  """
  require Logger
  alias Eldritch.Being.Deck

  def update_components(system) do
    for {pid, being_id} <- Eldritch.Entities.members(system), do: remind(pid, being_id)
  end

  defp remind(being_server, being_id) do
    result =
      Cosmos.Entity.Server.get_and_update_component(being_server, "deck", fn comp ->
        {card, deck} = Deck.whisper(comp.value)
        {card, %{comp | value: deck}}
      end)

    case result do
      %{"front" => front} ->
        name = Cosmos.Entity.Server.value(being_server, "name")
        owned? = Cosmos.Entity.Server.value(being_server, "ownership", %{})["owner"] != nil
        Logger.debug("#{name} whispers: #{front}")

        # cards belong to their owner: the chronicle only names the commons' cards
        text =
          if owned?, do: "#{name} whispers an incantation.", else: "#{name} whispers \"#{front}\""

        Eldritch.Chronicle.record(:whisper, text, %{"beings" => [being_id]})

      _ ->
        :ok
    end
  end
end
