defmodule CAIData.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      CAIData.Repo,
      {Phoenix.PubSub, name: :ps2_events},
      {CAIData.SessionHandler, %{}},
      {CAIData.EventHandler,
       [
         events: [
           "GainExperience",
           "Death",
           "VehicleDestroy",
           "PlayerLogin",
           "PlayerLogout",
           "PlayerFacilityCapture",
           "PlayerFacilityDefend",
           "BattleRankUp",
           "MetagameEvent",
           "ContinentUnlock",
           "ContinentLock"
         ],
         worlds: ["Connery"],
         characters: ["all"]
       ]}
    ]

    opts = [strategy: :one_for_one, name: CAIData.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
