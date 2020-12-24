defmodule CAIData.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      CAIData.Repo,
      { Phoenix.PubSub, name: :ps2_events },
			{ CAIData.SessionHandler, {%{}, []}},
			CAIData.WorldState,
      { CAIData.EventHandler,
				[
					events: [
						"GainExperience",
						"Death",
						"VehicleDestroy",
						"PlayerLogin",
						"PlayerLogout",
						"PlayerFacilityCapture",
						"PlayerFacilityDefend",
						"ItemAdded",
						"BattleRankUp",
						"MetagameEvent",
						"ContinentUnlock",
						"ContinentLock"
					],
					worlds: ["all"],
					characters: ["all"]
				]
			}
    ]

    opts = [strategy: :one_for_one, name: CAIData.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
