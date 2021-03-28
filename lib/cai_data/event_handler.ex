defmodule CAIData.EventHandler do
	use PS2.SocketClient
	require Logger

	import Ecto.Query
	import PS2.API.QueryBuilder

	alias PS2.API.{Query, Join}
	alias CAIData.Repo
	alias CAIData.CharacterSession
	alias CAIData.SessionHandler
	alias Phoenix.PubSub

  def start_link(subscriptions) do
    PS2.SocketClient.start_link(__MODULE__, subscriptions)
	end

	# PS2 Events
	def handle_event({_event, %{"character_id" => "0"}}), do: nil

	def handle_event({"GainExperience", %{"character_id" => character_id, "amount" => xp_amount, "experience_id" => xp_id} = payload}) do
		case SessionHandler.get(character_id) do
			{:ok, %CharacterSession{xp_types: xp_types} = session} ->
				xp = String.to_integer(xp_amount)
				CharacterSession.changeset(session, %{xp_earned: session.xp_earned + xp, xp_types: Map.update(xp_types, xp_id, xp, & &1 + xp)})
				|> SessionHandler.update()
			_ -> nil
		end
		if xp_id == "1520" do
			CAIData.WorldState.damage_bastion(payload["world_id"], payload["zone_id"], payload["other_id"])
		end
	end

	def handle_event({"Death", %{"character_id" => character_id, "attacker_character_id" => attacker_id, "attacker_weapon_id" => weapon_id, "attacker_vehicle_id" => vehicle_id, "is_headshot" => is_headshot}}) do
		# If the weapon is considered an IvI weapon and the attacker is not in a vehicle, is_ivi_kill = true
		is_ivi_kill = Enum.member?(CAIData.ivi_weapon_ids, weapon_id) and vehicle_id == "0"
		is_headshot = String.to_integer(is_headshot)

		case SessionHandler.get(character_id) do
			{:ok, %CharacterSession{} = session} ->
				CharacterSession.changeset(session, %{deaths: session.deaths + 1, deaths_ivi: session.deaths_ivi + (is_ivi_kill == true && 1 || 0)})
				|> SessionHandler.update()
			_ -> nil
		end
		case SessionHandler.get(attacker_id) do
			{:ok, %CharacterSession{} = session} ->
				changes = %{
					kills: session.kills + 1,
					kills_hs: session.kills_hs + is_headshot,
					kills_ivi: session.kills_ivi + 1,
					kills_hs_ivi: session.kills_hs_ivi + (is_ivi_kill and is_headshot == 1 && 1 || 0)
				}
				CharacterSession.changeset(session, changes)
				|> SessionHandler.update()
			_ -> nil
		end
	end

	def handle_event({"PlayerLogin", %{"character_id" => character_id, "timestamp" => timestamp}}) do
		SessionHandler.put(character_id, timestamp)
	end

	def handle_event({"PlayerLogout", %{"character_id" => character_id, "timestamp" => timestamp}}) do
		SessionHandler.close(character_id, timestamp)
	end

	def handle_event({"VehicleDestroy", %{"attacker_vehicle_id" => "0"}}), do: nil
	def handle_event({"VehicleDestroy", %{"character_id" => character_id, "attacker_character_id" => attacker_id, "attacker_vehicle_id" => attacker_vehicle_id}}) do
		with {:ok, vehicle} <- Map.fetch(CAIData.vehicle_info, attacker_vehicle_id) do
			case SessionHandler.get(character_id) do
				{:ok, %CharacterSession{vehicles_lost: vehicles_lost} = session} ->
					CharacterSession.changeset(session, %{
						vehicles_lost: Map.update(vehicles_lost, vehicle["name"], 1, &(&1 + 1)),
						nanites_lost: session.nanites_lost + String.to_integer(vehicle["cost"]),
						vehicle_deaths: session.vehicle_deaths + 1
					})
					|> SessionHandler.update()
				_ -> nil
			end
			case SessionHandler.get(attacker_id) do
				{:ok, %CharacterSession{vehicles_destroyed: vehicles_destroyed} = session} when attacker_id != character_id ->
					CharacterSession.changeset(session, %{
						vehicles_destroyed: Map.update(vehicles_destroyed, vehicle["name"], 1, &(&1 + 1)),
						nanites_destroyed: session.nanites_destroyed + String.to_integer(vehicle["cost"]),
						vehicle_kills: session.vehicle_kills + 1
					})
					|> SessionHandler.update()
				_ -> nil
			end
		end
	end

	def handle_event({"PlayerFacilityCapture", %{"character_id" => character_id}}) do
		case SessionHandler.get(character_id) do
			{:ok, %CharacterSession{} = session} ->
				CharacterSession.changeset(session, %{base_captures: session.base_captures + 1})
				|> SessionHandler.update()
			_ -> nil
		end
	end

	def handle_event({"PlayerFacilityDefend", %{"character_id" => character_id}}) do
		case SessionHandler.get(character_id) do
			{:ok, %CharacterSession{} = session} ->
				CharacterSession.changeset(session, %{base_defends: session.base_defends + 1})
				|> SessionHandler.update()
			_ -> nil
		end
	end

	# def handle_event({"FacilityControl", payload}), do: nil
	def handle_event({"ItemAdded", %{"context" => "GenericTerminalTransaction", "item_id" => "6008912", "character_id" => character_id, "world_id" => world_id, "zone_id" => zone_id}}) do
		character_query = Query.new(collection: "single_character_by_id") |> term("character_id", character_id) |> show(["character_id", "faction_id"]) |> join(Join.new(collection: "outfit") |> show(["outfit_id", "alias"]))
		with {:ok, %{"faction_id" => faction_id, "alias" => outfit_alias}} <- PS2.API.send_query(character_query) do
			CAIData.WorldState.put_bastion(world_id, zone_id, faction_id, outfit_alias)
		end
	end
	# def handle_event({"SkillAdded", payload}), do: nil
	# def handle_event({"AchievementEarned", payload}), do: nil
	def handle_event({"BattleRankUp", %{"character_id" => character_id, "battle_rank" => br}}) do
		case SessionHandler.get(character_id) do
			{:ok, %CharacterSession{} = session} ->
				CharacterSession.changeset(session, %{br_ups: [br | session.br_ups]})
				|> SessionHandler.update()
			_ -> nil
		end
	end

	# def handle_event({"MetagameEvent", %{"metagame_event_id" => metagame_event_id, "metagame_event_state" => "138"}}) do
	def handle_event({"MetagameEvent", %{"metagame_event_id" => metagame_event_id, "metagame_event_state" => "135"}}) do
		event_id = String.to_integer(metagame_event_id)
		query = from s in "event_subscriptions",
			where: ^event_id in s.event_ids,
			select: s.user_id
		user_ids = Repo.all(query)
		event =
			{ Map.get(CAIData.event_info, event_id), user_ids }
		PubSub.broadcast :ps2_events, "metagame", event
	end

	def handle_event({"ContinentLock", %{"world_id" => world_id, "zone_id" => zone_id}}) do
		event =
			{ Map.get(CAIData.world_info, world_id), Map.get(CAIData.zone_info, zone_id) }
		PubSub.broadcast :ps2_events, "zonelock", event
	end

	def handle_event({"ContinentUnlock", %{"world_id" => world_id, "zone_id" => zone_id}}) do
		world_id = String.to_integer(world_id)
		query = from s in "unlock_subscriptions",
			where: ^world_id in s.world_ids and ^zone_id in s.zone_ids,
			select: s.user_id
		user_ids = Repo.all(query)
		event =
			{ Map.get(CAIData.world_info, world_id), Map.get(CAIData.zone_info, zone_id), user_ids }
		PubSub.broadcast :ps2_events, "zoneunlock", event
	end

	# Catch-all callback.
  def handle_event(_event), do: nil
end
