defmodule Cosmos do
  @moduledoc """
  Documentation for `Cosmos`.
  """

  def get_data_path() do
    Application.fetch_env!(:cosmos, :data_path)
  end

  def get_persist_dir() do
    Application.fetch_env!(:cosmos, :local_db_dir)
    |> Path.absname()
  end
end
