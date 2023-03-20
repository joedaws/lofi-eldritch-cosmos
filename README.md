# Lofi Eldritch beings to study with

Simulation of a cosmos of eldritch beings trying to learn cooperation and social organization.

The `Cosmos` module is a work-in-progress implementation of an entity component system (ECS)
which will power the simulation.

# Creating new entities

Entities can be created using the module `Cosmos.Entity.Builder` module. To create a
new entity, with some of the standard attributes, use the build function whose
first argument is `{:new, :standard}`. For example,

``` elixir
new_entity = Cosmos.Entity.Builder.build({:new, :standard}, %{"name" => "Gor'lop"})
```
will create and spawn an entity worker for an entity named "Gor'lop". The build
method also adds the standard components for an entity (see function 
for definition of standard components).

The second argument can overwrite the default values used to create the standard
components of an entity.

# Current feature considerations 

- Consider using [quantum](https://hexdocs.pm/quantum/readme.html) to schedule simulation-wide events and system-level updates.
- Create `Cosmos.System` module which sends messages to `Cosmos.SystemRegsitry` to update beings according to a fixed interval of time and also can be stopped or started.

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
