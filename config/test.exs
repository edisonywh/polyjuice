import Config

config :polyjuice, Polyjuice.Repo,
  database: ":memory:",
  pool_size: 1,
  pool: Ecto.Adapters.SQL.Sandbox

config :logger, level: :warning
