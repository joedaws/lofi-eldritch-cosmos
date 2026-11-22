defmodule Lofi.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      LofiWeb.Telemetry,
      Lofi.Repo,
      # accounts live in their own SQLite database next to the cosmos;
      # migrations run on start so there is nothing to set up by hand
      {Ecto.Migrator,
       repos: Application.fetch_env!(:lofi, :ecto_repos),
       skip: not Application.get_env(:lofi, :migrate_on_start, true)},
      {Phoenix.PubSub, name: Lofi.PubSub},
      # one world snapshot per tick for every open page
      LofiWeb.WorldBroadcaster,
      LofiWeb.Endpoint
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Lofi.Supervisor)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    LofiWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
