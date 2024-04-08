defmodule Cosmos do
  @moduledoc """
  Documentation for `Cosmos`.
  """

  def get_persist_dir() do
    Application.fetch_env!(:cosmos, :local_db_dir)
  end

  def query(filter) do
    Cosmos.Database.query(filter)
    |> Enum.join(", ")
  end
end
