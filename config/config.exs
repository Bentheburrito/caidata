import Config

# For mix commands in dev enviroments, like "mix ecto.create"
config :caidata, CAIData.Repo,
database: "caidata",
username: "postgres",
password: "postgres",
hostname: "localhost"

config :caidata,
ecto_repos: [CAIData.Repo]
