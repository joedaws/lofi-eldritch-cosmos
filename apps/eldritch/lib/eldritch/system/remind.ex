defmodule Eldritch.System.Remind do
  require Logger

  def update_components(system) do
    Registry.dispatch(Cosmos.SystemRegistry, system, fn entries ->
      for {pid, _} <- entries, do: remind(pid)
    end)
  end

  @doc """
  Load the incantation for the being and return a message based on it's type.
  """
  defp remind(being_server) do
    {incantation_type, message} =
      case Cosmos.Entity.Server.component(being_server, "incantation").value do
        %{"front" => "", "back" => ""} ->
          {:empty_incantation, "No incantation"}

        %{"front" => declaration, "back" => ""} ->
          {:declarative_incantation, declaration}

        %{"front" => front_msg, "back" => back_msg} ->
          {:flash_incantation, [front_msg, back_msg]}
      end

    case incantation_type do
      :declarative_incantation -> Logger.info("Reminding about #{message}")
      :flash_incantation -> Logger.info("Reminding about \nfront: #{Enum.at(message,0)} \nback: #{Enum.at(message, 1)}")
      _ -> Logger.info("Nothing to remind")
    end
  end
end
