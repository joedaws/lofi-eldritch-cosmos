defmodule Eldritch.Entities do
  @moduledoc """
  Helpers for finding and reading the entities that make up the
  Eldritch cosmos.

  Every being has an `is_being` component and every node an `is_node`
  component; both are marker systems, so the `Cosmos.SystemRegistry`
  doubles as an index of all live beings and nodes.
  """

  @doc "`[{pid, entity_id}]` for all live beings"
  def beings(), do: members(:is_being)

  @doc "`[{pid, entity_id}]` for all live nodes"
  def nodes(), do: members(:is_node)

  def members(system_atom) do
    Cosmos.SystemRegistry
    |> Registry.lookup(system_atom)
    |> Enum.map(fn {pid, [entity_id]} -> {pid, entity_id} end)
    |> Enum.uniq_by(fn {_, entity_id} -> entity_id end)
  end

  @doc """
  Flattens an entity into a map of component name => value, plus "id".
  Returns nil when the entity server is gone.
  """
  def values(pid) when is_pid(pid) do
    try do
      pid |> Cosmos.Entity.Server.get() |> to_values()
    catch
      :exit, _ -> nil
    end
  end

  def to_values(%Cosmos.Entity{} = entity) do
    entity
    |> Cosmos.Entity.components()
    |> Map.new(fn comp -> {comp.name, comp.value} end)
    |> Map.put("id", entity.id)
  end

  @doc """
  `%{node_id => node_values}` for every live node
  """
  def node_map() do
    nodes()
    |> Enum.flat_map(fn {pid, _id} ->
      case values(pid) do
        nil -> []
        vals -> [{vals["id"], Map.put(vals, "pid", pid)}]
      end
    end)
    |> Map.new()
  end

  @doc """
  `[being_values]` for every live being
  """
  def being_list() do
    beings()
    |> Enum.flat_map(fn {pid, _id} ->
      case values(pid) do
        nil -> []
        vals -> [Map.put(vals, "pid", pid)]
      end
    end)
  end

  def alive?(being_values), do: Map.get(being_values, "status", "alive") != "faded"

  @doc """
  Converts arbitrary terms (MapSets, tuples, structs) into values
  that can be encoded as JSON.
  """
  def to_json(%MapSet{} = set), do: set |> MapSet.to_list() |> to_json()

  def to_json(%{__struct__: _} = struct), do: struct |> Map.from_struct() |> to_json()

  def to_json(map) when is_map(map) do
    Map.new(map, fn {k, v} -> {json_key(k), to_json(v)} end)
  end

  def to_json(list) when is_list(list), do: Enum.map(list, &to_json/1)
  def to_json(tuple) when is_tuple(tuple), do: tuple |> Tuple.to_list() |> to_json()
  def to_json(pid) when is_pid(pid), do: inspect(pid)

  def to_json(atom) when is_atom(atom) and atom not in [nil, true, false] do
    atom |> Atom.to_string() |> String.replace_prefix("Elixir.", "")
  end

  def to_json(other), do: other

  defp json_key(k) when is_binary(k), do: k
  defp json_key(k), do: k |> to_json() |> to_string()
end
