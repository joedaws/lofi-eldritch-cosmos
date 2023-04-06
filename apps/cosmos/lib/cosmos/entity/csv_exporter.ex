defmodule Cosmos.Entity.CsvExporter do
  def to_csv_string(entity) do
    Enum.map(entity.components, fn {_, %{id: _, system: system, value: value}} ->
      {system, value}
    end)
    |> Enum.map(fn {system, value} -> "#{system},#{value}\n" end)
  end

  def export(entity, file_name) do
    file = File.stream!(file_name)
    to_csv_string(entity) |> Enum.into(file)
  end
end
