Application.put_env(:polyjuice, PolyjuiceTest.Repo,
  database: ":memory:",
  pool_size: 1,
  pool: Ecto.Adapters.SQL.Sandbox
)

Application.put_env(:polyjuice, :ecto_repos, [PolyjuiceTest.Repo])

{:ok, _} = Application.ensure_all_started(:ecto_sql)
{:ok, _} = PolyjuiceTest.Repo.start_link()

Ecto.Adapters.SQL.Sandbox.mode(PolyjuiceTest.Repo, :manual)

ExUnit.start()

ExUnit.configure(
  exclude: [:skip],
  formatters: [ExUnit.CLIFormatter],
  colors: [enabled: true]
)


