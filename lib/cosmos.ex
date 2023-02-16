defmodule Cosmos do
  @moduledoc """
  Documentation for `Cosmos`.
  """

  def get_data_path() do
    Application.fetch_env!(:cosmos, :data_path)
  end
end
