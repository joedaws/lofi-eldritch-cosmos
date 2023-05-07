"""
Idea: Create a graph based on concentric circles with random connections
    between the circles

Example:
q----w----e----r----t
|    +              |
|    i----o----p++++y
|    |    |    |    |
u++++f    b++++c    |
|    |         |    |
|    d----s----a++++l
|                   |
h---------j----k----z

+ are edges between circles and
- are edges between nodes within the same circle
"""

num_circles = 3
# each circle has same number of nodes
num_nodes_per_circle = 10
# between circles there are between min_connections and max_connections edges
min_connections = 3
max_connections = 7

circles_lists =
  for c <- 1..num_circles,
  do: Enum.map(1..(num_nodes_per_circle), fn _ -> Eldritch.Node.Builder.build({:new, :node}) end)


# TODO connect nodes between different circles
# for circle_lists,
