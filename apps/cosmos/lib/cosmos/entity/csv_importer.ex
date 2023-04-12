defmodule Cosmos.Entity.CsvImporter do
  @doc """
  file_name is assumed to be the name of a file in
  the data_path of the application
  """
  def import(file_name) do
    data_path = Cosmos.get_data_path()
    path = Path.join(data_path, file_name)

    entity =
      File.stream!(path)
      |> Stream.map(&String.replace(&1, "\n", ""))
      |> Stream.map(&String.split(&1, ","))
      |> Stream.map(&List.to_tuple/1)
      |> Enum.map(fn {system, value} -> %{system: system, value: value} end)
      |> Cosmos.Entity.new()

    ichor_comp_id = Map.get(Cosmos.Entity.component(entity, "ichor"), :id)

    Cosmos.Entity.update_component(entity, ichor_comp_id, fn comp ->
      %{comp | value: String.to_integer(comp.value)}
    end)
  end
end
