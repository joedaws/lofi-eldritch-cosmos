defmodule Eldritch.Being do
  @moduledoc """
  This module is responsible for high level interactions
  with generic beings.
  """
  alias Eldritch.Being.{Actions, Incantation}

  @max_ichor 200

  def max_ichor(), do: @max_ichor

  @doc """
  Get a being given it's being/entity id.
  """
  def get(being_id) do
    Cosmos.Entity.Cache.server_process(being_id)
    |> Cosmos.Entity.Server.get()
  end

  @doc """
  Like `get/1` but returns `{:ok, entity}` or `:error` for unknown ids
  instead of creating an empty entity.
  """
  def fetch(being_id) do
    with pid when is_pid(pid) <- Cosmos.Entity.Cache.existing_server_process(being_id),
         entity <- Cosmos.Entity.Server.get(pid),
         true <- Cosmos.Entity.component(entity, "is_being") != nil do
      {:ok, entity}
    else
      _ -> :error
    end
  end

  def component(being_id, component_name) do
    Cosmos.Entity.Cache.server_process(being_id)
    |> Cosmos.Entity.Server.component(component_name)
  end

  def update(being_id, component, updater_function) do
    Cosmos.Entity.Cache.server_process(being_id)
    |> Cosmos.Entity.Server.update_component(component, updater_function)
  end

  @doc "ids of all live beings"
  def all_ids() do
    Eldritch.Entities.beings() |> Enum.map(&elem(&1, 1))
  end

  @doc """
  Replace the incantation (resets its spaced repetition progress)
  """
  def set_incantation(being_id, front, back) do
    with {:ok, _} <- fetch(being_id) do
      update(being_id, "incantation", fn comp -> %{comp | value: Incantation.new(front, back)} end)
      :ok
    end
  end

  @doc """
  Answer the incantation a being is whispering.

  Returns `{:ok, result_map}`, `{:error, :not_awaiting, ms_until_due}`
  or `:error` for unknown beings. A correct answer feeds the being
  ichor, which can even call a faded being back from the void.
  """
  def recall(being_id, answer) do
    with {:ok, entity} <- fetch(being_id) do
      pid = Cosmos.Entity.Cache.server_process(being_id)
      vals = Eldritch.Entities.to_values(entity)
      incantation = Incantation.normalize(vals["incantation"])

      if incantation["awaiting"] do
        correct = Incantation.correct?(incantation, answer)

        new_incantation =
          if correct, do: Incantation.promote(incantation), else: Incantation.demote(incantation)

        Cosmos.Entity.Server.update_component(pid, "incantation", fn comp ->
          %{comp | value: new_incantation}
        end)

        gain = if correct, do: Incantation.reward(incantation), else: 0
        ichor = if gain > 0, do: Actions.change_ichor(pid, gain), else: vals["ichor"]

        if correct and vals["status"] == "faded" and ichor > 0, do: revive(being_id, vals)

        Eldritch.Chronicle.record(
          :recall,
          if(correct,
            do: "#{vals["name"]}'s incantation was answered true. Ichor surges (+#{gain}).",
            else: "#{vals["name"]}'s incantation was answered falsely. It returns to the first box."
          ),
          %{"beings" => [being_id]}
        )

        {:ok,
         %{
           "correct" => correct,
           "expected" => incantation["back"],
           "ichor_gain" => gain,
           "ichor" => ichor,
           "box" => new_incantation["box"],
           "due_at" => new_incantation["due_at"]
         }}
      else
        {:error, :not_awaiting, max(0, incantation["due_at"] - System.system_time(:millisecond))}
      end
    end
  end

  @doc """
  Draw a being to a node of your choosing
  """
  def beckon(being_id, node_id) do
    with {:ok, entity} <- fetch(being_id) do
      vals = Eldritch.Entities.to_values(entity)

      if vals["status"] == "faded" do
        {:error, :faded}
      else
        with :ok <- Actions.move_to_node(being_id, node_id) do
          set_thought(being_id, "beckon", "Something calls me onward...")
          :ok
        end
      end
    end
  end

  @doc """
  The being's ichor is spent: it stops acting and leaves its node's
  occupants, but its remains (and incantation) linger.
  """
  def fade(being_id, vals) do
    pid = Cosmos.Entity.Cache.server_process(being_id)
    Cosmos.Entity.Server.update_component(pid, "status", fn comp -> %{comp | value: "faded"} end)
    Actions.leave_node(being_id, vals["at_node"])
    set_thought(being_id, "faded", "...")

    Eldritch.Chronicle.record(:fade, "#{vals["name"]} has faded into the void.", %{
      "beings" => [being_id],
      "node" => vals["at_node"]
    })
  end

  def revive(being_id, vals) do
    pid = Cosmos.Entity.Cache.server_process(being_id)
    Cosmos.Entity.Server.update_component(pid, "status", fn comp -> %{comp | value: "alive"} end)

    if vals["at_node"] do
      Actions.move_to_node(being_id, vals["at_node"])
    end

    set_thought(being_id, "revived", "I was called back by a remembered word.")

    Eldritch.Chronicle.record(:revive, "#{vals["name"]} is called back from the void!", %{
      "beings" => [being_id],
      "node" => vals["at_node"]
    })
  end

  def set_thought(being_id, intent, thought) do
    update(being_id, "volition", fn comp ->
      %{comp | value: Map.merge(comp.value, %{"intent" => intent, "thought" => thought})}
    end)
  end
end
