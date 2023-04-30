ExUnit.start()

# add in some placeholder systems that components can belong to
# second argument is cycle_duration and is not used for the test
Cosmos.System.add(:attribute, 10 * 1000)
Cosmos.System.add(:temporal_decay, 10 * 1000)

# setup test beings
ExUnit.after_suite(fn _ ->
  Enum.map(
    Path.wildcard(Path.join(Cosmos.get_persist_dir(), "*")),
    fn file_path -> File.rm(file_path) end
  )
end)
