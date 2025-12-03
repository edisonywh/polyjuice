# Start the configuration system
Application.load(:polyjuice)

# Ensure all required applications are started
{:ok, _} = Application.ensure_all_started(:ecto_sql)

# Start the repo
{:ok, _} = Polyjuice.Repo.start_link()

# Configure sandbox mode for tests
Ecto.Adapters.SQL.Sandbox.mode(Polyjuice.Repo, :manual)

# Start ExUnit
ExUnit.start()

ExUnit.configure(
  exclude: [:skip],
  formatters: [ExUnit.CLIFormatter],
  colors: [enabled: true]
)
