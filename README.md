# Lofi Eldritch beings to study with

Simulation of a cosmos of eldritch beings trying to learn cooperation and social organization.

    

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
iex(2)> server = Cosmos.Entity.Server.start()
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
