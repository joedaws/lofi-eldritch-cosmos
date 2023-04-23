ExUnit.start()

# add in some placeholder systems that components can belong to
# second argument is cycle_duration and is not used for the test
Cosmos.System.add(:attribute, 10 * 1000)
Cosmos.System.add(:temporal_decay, 10 * 1000)
