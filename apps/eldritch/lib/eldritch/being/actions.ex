defmodule Eldritch.Being.Actions do
  @moduledoc """
  Actions which change where beings are and what they hold.
  """
  require Logger

  @doc """
  Moves a being to a node, keeping the `occupants` of the previous and
  the new node consistent. Returns `:ok` or `{:error, reason}`.
  """
  def move_to_node(being_id, node_id) do
    with being_server when is_pid(being_server) <-
           Cosmos.Entity.Cache.existing_server_process(being_id) || {:error, :unknown_being},
         node_server when is_pid(node_server) <-
           Cosmos.Entity.Cache.existing_server_process(node_id) || {:error, :unknown_node} do
      old_node_id = Cosmos.Entity.Server.value(being_server, "at_node")

      # remove being from the node it currently occupies
      if old_node_id != nil and old_node_id != node_id do
        case Cosmos.Entity.Cache.existing_server_process(old_node_id) do
          nil -> :ok
          old_node_server -> remove_occupant(old_node_server, being_id)
        end
      end

      add_occupant(node_server, being_id)

      # update the at_node component of a being
      Cosmos.Entity.Server.update_component(being_server, "at_node", fn comp ->
        %{comp | value: node_id}
      end)

      :ok
    end
  end

  @doc """
  Removes a being from the occupants of its node without changing its
  `at_node` (used when a being fades: its remains stay where it fell).
  """
  def leave_node(being_id, node_id) do
    case node_id && Cosmos.Entity.Cache.existing_server_process(node_id) do
      pid when is_pid(pid) -> remove_occupant(pid, being_id)
      _ -> :ok
    end
  end

  def add_occupant(node_server, being_id) do
    Cosmos.Entity.Server.update_component(node_server, "occupants", fn comp ->
      Map.update!(comp, :value, fn occupants -> MapSet.put(occupants, being_id) end)
    end)
  end

  def remove_occupant(node_server, being_id) do
    Cosmos.Entity.Server.update_component(node_server, "occupants", fn comp ->
      Map.update!(comp, :value, fn occupants -> MapSet.delete(occupants, being_id) end)
    end)
  end

  @doc """
  Adds `amount` (may be negative) to a being's ichor, clamped to
  `0..max_ichor`. Returns the new ichor value.
  """
  def change_ichor(being_server, amount) do
    result =
      Cosmos.Entity.Server.get_and_update_component(being_server, "ichor", fn comp ->
        new_value = (comp.value + amount) |> max(0) |> min(Eldritch.Being.max_ichor())
        {new_value, %{comp | value: new_value}}
      end)

    case result do
      {:error, _} -> 0
      value -> value
    end
  end

  @doc """
  Takes up to `amount` units of `resource` out of a being's inventory.
  Returns the number of units actually taken.
  """
  def take_resource(being_server, resource, amount) do
    result =
      Cosmos.Entity.Server.get_and_update_component(being_server, "inventory", fn comp ->
        have = get_in(comp.value, ["resources", resource]) || 0
        taken = min(have, amount)
        resources = Map.put(comp.value["resources"], resource, have - taken)
        resources = if have - taken == 0, do: Map.delete(resources, resource), else: resources
        {taken, %{comp | value: Map.put(comp.value, "resources", resources)}}
      end)

    case result do
      {:error, _} -> 0
      taken -> taken
    end
  end

  def give_resource(being_server, resource, amount) when amount > 0 do
    Cosmos.Entity.Server.update_component(being_server, "inventory", fn comp ->
      Map.update!(comp, :value, fn inventory ->
        Map.update!(inventory, "resources", fn resources ->
          Map.update(resources, resource, amount, &(&1 + amount))
        end)
      end)
    end)
  end

  def give_resource(_being_server, _resource, _amount), do: :ok
end
