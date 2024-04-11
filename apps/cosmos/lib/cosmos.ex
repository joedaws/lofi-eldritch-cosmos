defmodule Cosmos do
  @moduledoc """
  Documentation for `Cosmos`.
  """

  def get_persist_dir() do
    Application.fetch_env!(:cosmos, :local_db_dir)
  end

  def query(filter) do
    result = Cosmos.Database.query(filter)
    case result do
      "" -> "None"
      _ -> Enum.join(result, ", ")
    end
  end
end
