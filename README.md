# Lofi Eldritch beings to study with

Simulation of a cosmos of eldritch beings trying to learn cooperation and social organization.

- The `Cosmos` application is a work-in-progress implementation of an entity component system (ECS)
which will power the simulation.

- Modules in the `Eldritch` name space are used to construct and interact with specific
kinds of entities such as `Being`.

# Cosmos ECS

## Creating new entities

Entities can be created using the a builder module. 
For example, the `Eldritch.Being.Builder` module can be used to create a
new being entity, with some of the standard attributes, use the build function
with argument `{:new, :being, :standard}`. For example, after the Cosmos supervisor
has been started one can run
``` elixir
being_entity_id = Eldritch.Being.Builder.build({:new, :being, :standard}, %{"name" => "Gor'lop"})
```
to create and spawn an entity worker for a being entity named "Gor'lop". The being's
`entity_id` is returned so that we can fetch it's worker process using
`Cosmos.Entity.Cache.server_process(being_entity_id)`.
The build function called in this way adds the standard components for a being.

The second argument can overwrite the default values used to create the standard
components of an entity.

## Starting and stopping systems

System are controlled by `GenServers` (see `Cosmos.System.TemporalDecay` for an example).
The Genserver that powers each system is started when the Cosmos is started, but will 
not act on components of entities until being turned on.
Systems can be started or stopped using `Cosmos.System.on/1` and `Cosmos.System.off/1`
where the argument is the system atom (e.g. `:temporal_decay`).

# Current feature considerations 

- Create a `Behaviour` for systems. Create callbacks which all systems use.
- [quantum](https://hexdocs.pm/quantum/readme.html) will be good for systems that need
  to be run at intervals of minutes or hours (such as full backups maybe), but won't be
  suitable for systems that need to run every n seconds. For this case, building a 
  GenServer to handle the message will work. I plan to keep quantum integrated
  and use it to schedule long term events.
- Read [runtime configuration of quantum scheduler](https://hexdocs.pm/quantum/runtime-configuration.html)
  This will allow for systems to be turned on and off.

# Testing

## Testing database workers

Launch the elixir REPL with
``` shell
iex -S mix
```

Then run something like to make sure that database workers
are behaving as expected.
``` elixir
iex(1)> Cosmos.Entity.Cache.start_link()
{:ok, #PID<0.215.0>}
iex(2)> server = Cosmos.Entity.Server.start_link("jorsa")
{:ok, #PID<0.221.0>}
iex(3)> {_, server} = server
{:ok, #PID<0.221.0>}
iex(4)> entity = Cosmos.Entity.Server.get(server)
%Cosmos.Entity{
  id: "2MXHjNmnZAfLUZToIExXE5xrXiL",
  components: %{},
  auto_component_id: 1
}
iex(5)> comp = Cosmos.Entity.Component.new("name", :static, "johnson")
%Cosmos.Entity.Component{name: "name", type: :static, value: "johnson", id: nil}
iex(6)> Cosmos.Entity.Server.add_component(server, comp)
:ok
#PID<0.217.0> was chosen
```
