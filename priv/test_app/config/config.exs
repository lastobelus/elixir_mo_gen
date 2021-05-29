import Config

config :test_app, TestApp.Repo,
  database: "elixir_mo_gen_test",
  username: "postgres",
  password: "postgres",
  hostname: "localhost"
config :test_app, ecto_repos: [TestApp.Repo]
