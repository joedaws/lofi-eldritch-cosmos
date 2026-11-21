# register every system before tests create components
Eldritch.Simulation.initialize_systems()

ExUnit.after_suite(fn _ ->
  Eldritch.Genesis.reset()
end)

ExUnit.start()
