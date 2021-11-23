defmodule CAIData.EventHandler do
  use PS2.SocketClient
  require Logger

  import Ecto.Query
  import PS2.API.QueryBuilder

  alias PS2.API.{Query, Join, QueryResult}
  alias CAIData.Repo
  alias CAIData.CharacterSession
  alias CAIData.SessionHandler
  alias Phoenix.PubSub

  def start_link(subscriptions) do
    PS2.SocketClient.start_link(__MODULE__, subscriptions)
  end

  # PS2 Events
  def handle_event({_event, %{"character_id" => "0"}}), do: nil

  def handle_event(
        {"GainExperience",
         %{"character_id" => character_id, "amount" => xp_amount, "experience_id" => xp_id} =
           payload}
      ) do
    with {:ok, %CharacterSession{xp_types: xp_types} = session} <- SessionHandler.get(character_id) do
      xp = String.to_integer(xp_amount)

      CharacterSession.changeset(session, %{
        xp_earned: session.xp_earned + xp,
        xp_types: Map.update(xp_types, xp_id, xp, &(&1 + xp))
      })
      |> SessionHandler.update()
    end

    if xp_id == "1520" do
      CAIData.WorldState.damage_bastion(
        payload["world_id"],
        payload["zone_id"],
        payload["other_id"]
      )
    end
  end

  def handle_event(
        {"Death",
         %{
           "character_id" => character_id,
           "attacker_character_id" => attacker_id,
           "attacker_weapon_id" => weapon_id,
           "attacker_vehicle_id" => vehicle_id,
           "is_headshot" => is_headshot
         }}
      ) do
    # If the weapon is considered an IvI weapon and the attacker is not in a vehicle, ivi_kill = 1, else ivi_kill = 0
    ivi_kill =
      if Enum.member?(CAIData.ivi_weapon_ids(), weapon_id) and vehicle_id == "0",
        do: 1,
        else: 0
    headshot_kill = String.to_integer(is_headshot)

    with {:ok, %CharacterSession{} = session} <- SessionHandler.get(character_id) do
      CharacterSession.changeset(session, %{
        deaths: session.deaths + 1,
        deaths_ivi: session.deaths_ivi + ivi_kill
      })
      |> SessionHandler.update()
    end

    with {:ok, %CharacterSession{} = session} <- SessionHandler.get(attacker_id) do
      CharacterSession.changeset(session, %{
        kills: session.kills + 1,
        kills_hs: session.kills_hs + headshot_kill,
        kills_ivi: session.kills_ivi + ivi_kill,
        kills_hs_ivi: session.kills_hs_ivi + (Bitwise.&&&(ivi_kill, headshot_kill))
      })
      |> SessionHandler.update()
    end
  end

  def handle_event({"PlayerLogin", %{"character_id" => character_id, "timestamp" => timestamp}}) do
    SessionHandler.put(character_id, timestamp)
  end

  def handle_event({"PlayerLogout", %{"character_id" => character_id, "timestamp" => timestamp}}) do
    SessionHandler.close(character_id, timestamp)
  end

  def handle_event({"VehicleDestroy", %{"attacker_vehicle_id" => "0"}}), do: nil

  def handle_event(
        {"VehicleDestroy",
         %{
           "character_id" => character_id,
           "vehicle_id" => vehicle_id,
           "attacker_character_id" => attacker_id
         }}
      ) do
    with {:ok, vehicle} <- Map.fetch(CAIData.vehicle_info(), vehicle_id) do
      with {:ok, %CharacterSession{vehicles_lost: vehicles_lost} = session} <- SessionHandler.get(character_id) do
        CharacterSession.changeset(session, %{
          vehicles_lost: Map.update(vehicles_lost, vehicle["name"], 1, &(&1 + 1)),
          nanites_lost: session.nanites_lost + String.to_integer(vehicle["cost"]),
          vehicle_deaths: session.vehicle_deaths + 1
        })
        |> SessionHandler.update()
      end

      with {:ok, %CharacterSession{vehicles_destroyed: vehicles_destroyed} = session}
           when attacker_id != character_id <- SessionHandler.get(attacker_id) do

        CharacterSession.changeset(session, %{
          vehicles_destroyed: Map.update(vehicles_destroyed, vehicle["name"], 1, &(&1 + 1)),
          nanites_destroyed: session.nanites_destroyed + String.to_integer(vehicle["cost"]),
          vehicle_kills: session.vehicle_kills + 1
        })
        |> SessionHandler.update()
      end
    end
  end

  def handle_event({"PlayerFacilityCapture", %{"character_id" => character_id}}) do
    with {:ok, %CharacterSession{} = session} <- SessionHandler.get(character_id) do
      CharacterSession.changeset(session, %{base_captures: session.base_captures + 1})
      |> SessionHandler.update()
    end
  end

  def handle_event({"PlayerFacilityDefend", %{"character_id" => character_id}}) do
    with {:ok, %CharacterSession{} = session} <- SessionHandler.get(character_id) do
      CharacterSession.changeset(session, %{base_defends: session.base_defends + 1})
      |> SessionHandler.update()
    end
  end

  # def handle_event({"FacilityControl", payload}), do: nil
  def handle_event(
        {"ItemAdded",
         %{
           "context" => "GenericTerminalTransaction",
           "item_id" => "6008912",
           "character_id" => character_id,
           "world_id" => world_id,
           "zone_id" => zone_id
         }}
      ) do
    character_query =
      Query.new(collection: "single_character_by_id")
      |> term("character_id", character_id)
      |> show(["character_id", "faction_id"])
      |> join(Join.new(collection: "outfit") |> show(["outfit_id", "alias"]))

    with {:ok, %QueryResult{data: %{"faction_id" => faction_id, "alias" => outfit_alias}}} <-
           PS2.API.query_one(character_query) do
      CAIData.WorldState.put_bastion(world_id, zone_id, faction_id, outfit_alias)
    end
  end

  # def handle_event({"SkillAdded", payload}), do: nil
  # def handle_event({"AchievementEarned", payload}), do: nil
  def handle_event({"BattleRankUp", %{"character_id" => character_id, "battle_rank" => br}}) do
    with {:ok, %CharacterSession{} = session} <- SessionHandler.get(character_id) do
      CharacterSession.changeset(session, %{br_ups: [br | session.br_ups]})
      |> SessionHandler.update()
    end
  end

  # Metagame end
  def handle_event({"MetagameEvent", %{"metagame_event_id" => event_id_str, "metagame_event_state" => "138"}}) do
    event_id = String.to_integer(event_id_str)

    event = {:metagame_end, Map.get(CAIData.event_info(), event_id), []}
    PubSub.broadcast(:ps2_events, "game_stats", event)
  end

  # Metagame start
  def handle_event(
        {"MetagameEvent",
         %{"metagame_event_id" => event_id_str, "metagame_event_state" => "135"}}
      ) do
    event_id = String.to_integer(event_id_str)

    query =
      from(s in "event_subscriptions",
        where: ^event_id in s.event_ids,
        select: s.user_id
      )

    user_ids = Repo.all(query)
    event = {:metagame_start, Map.get(CAIData.event_info(), event_id_str), user_ids}
    PubSub.broadcast(:ps2_events, "game_status", event)
  end

  def handle_event({"ContinentLock", %{"world_id" => world_id, "zone_id" => zone_id}}) do
    event = {:lock, Map.get(CAIData.world_info(), world_id), Map.get(CAIData.zone_info(), zone_id), []}
    PubSub.broadcast(:ps2_events, "game_status", event)
  end

  def handle_event({"ContinentUnlock", %{"world_id" => world_id_str, "zone_id" => zone_id_str}}) do
    world_id = String.to_integer(world_id_str)
    zone_id = String.to_integer(zone_id_str)

    query =
      from(s in "unlock_subscriptions",
        where: ^world_id in s.world_ids and ^zone_id in s.zone_ids,
        select: s.user_id
      )

    user_ids = Repo.all(query)

    event = {:unlock, Map.get(CAIData.world_info(), world_id_str), Map.get(CAIData.zone_info(), zone_id_str), user_ids}
    PubSub.broadcast(:ps2_events, "game_status", event)
  end

  # Catch-all callback.
  def handle_event(_event), do: nil
end
