# Generates a landscape of nodes on concentric rings with random
# connections between neighbouring rings (see Eldritch.Landscape).
#
#   mix run scripts/dev/landscape.exs
Eldritch.Simulation.initialize_systems()
node_ids = Eldritch.Landscape.generate(rings: [6, 10, 14])
Eldritch.Genesis.flush()
IO.puts("created #{length(node_ids)} nodes")
