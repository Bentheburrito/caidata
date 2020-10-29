import Config

config :caidata, CAIData.Repo,
  database: "caidata",
  username: System.get_env("DB_USER"),
  password: System.get_env("DB_PASS"),
  hostname: System.get_env("DB_HOST")

config :caidata, ecto_repos: [CAIData.Repo]

config :planetside_api, service_id: System.get_env("SERVICE_ID")
