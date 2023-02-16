defmodule Cosmos.Entity.CsvExporter do
  def to_csv_string(entity) do
    Enum.map(entity.components, fn {_, %{id: _, type: type, value: value}} -> {type, value} end)
    |> Enum.map(fn {type, value} -> "#{type},#{value}\n" end)
  end

  def export(entity, file_name) do
    file = File.stream!(file_name)
    to_csv_string(entity) |> Enum.into(file)
  end
end
