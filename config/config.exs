import Config

config :polyjuice, :ecto_repos, [Polyjuice.Repo]

# Import environment-specific config files
if File.exists?("#{__DIR__}/#{config_env()}.exs") do
  import_config "#{config_env()}.exs"
end
