defmodule Cosmos.Application do
  require Logger
  use Application

  @data_dir_app_name "lofi-eldritch-cosmos"

  def start(_, _) do
    Application.put_env(:cosmos, :local_db_dir, data_dir())
    Cosmos.Supervisor.start_link()
  end

  @doc """
  non-configuration, persistent data goes here
  """
  def data_dir do
    System.get_env("XDG_DATA_HOME")
    |> fallback(Path.join([System.user_home!(), ".local", "share"]))
    |> Path.join(@data_dir_app_name)
    |> ensure_dir_exists()
  end

  @doc """
  configuration data goes here
  """
  def config_dir do
    System.get_env("XDG_CONFIG_HOME")
    |> fallback(Path.join([System.user_home!(), ".config"]))
    |> Path.join(@data_dir_app_name)
    |> ensure_dir_exists()
  end


  @doc """
  ephermeral data that can be safely deleted goes here
  """
  def cache_dir do
    System.get_env("XDG_CACHE_HOME")
    |> fallback(Path.join([System.user_home!(), ".cache"]))
    |> Path.join(@data_dir_app_name)
    |> ensure_dir_exists()
  end

  defp fallback(nil, fallback_path), do: fallback_path
  defp fallback(path, _), do: path

  defp ensure_dir_exists(path) do
    File.mkdir_p!(path)
    path
  end
end
