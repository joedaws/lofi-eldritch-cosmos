defmodule Eldritch.System.Remind do
  @moduledoc """
  Spaced repetition: when a being's incantation comes due the being
  begins to whisper it and waits for someone to answer
  (see `Eldritch.Being.recall/2`).
  """
  require Logger
  alias Eldritch.Being.Incantation

  def update_components(system) do
    for {pid, being_id} <- Eldritch.Entities.members(system), do: remind(pid, being_id)
  end

  defp remind(being_server, being_id) do
    result =
      Cosmos.Entity.Server.get_and_update_component(being_server, "incantation", fn comp ->
        incantation = Incantation.normalize(comp.value)

        if not incantation["awaiting"] and Incantation.type(incantation) != :empty and
             Incantation.due?(incantation) do
          {{:whisper, incantation}, %{comp | value: %{incantation | "awaiting" => true}}}
        else
          {:quiet, %{comp | value: incantation}}
        end
      end)

    case result do
      {:whisper, incantation} ->
        name = Cosmos.Entity.Server.value(being_server, "name")
        Logger.info("#{name} whispers: #{incantation["front"]}")

        Eldritch.Chronicle.record(:whisper, "#{name} whispers \"#{incantation["front"]}\"", %{
          "beings" => [being_id]
        })

      _ ->
        :ok
    end
  end
end
