defmodule CAIData.EventHandler do
	use PS2.SocketClient
	require Logger

	import PS2.API.QueryBuilder
	import Ecto.Query

	alias PS2.API.{Query, Join}
	alias CAIData.Repo
	alias CAIData.CharacterSession
	alias CAIData.SessionHandler
	alias Phoenix.PubSub

  def start_link(subscriptions) do
    PS2.SocketClient.start_link(__MODULE__, subscriptions)
	end


	# Might be able to pattern match on unique patterns first (like login/out), then those with attacker_ids, and then the ones with character_id
	# PS2 Events
	def handle_event({_event, %{"character_id" => "0"}}), do: nil

	def handle_event({"GainExperience", %{"character_id" => character_id, "amount" => xp_amount, "experience_id" => xp_id}}) do
		case SessionHandler.get(character_id) do
			{:ok, %CharacterSession{xp_types: %{^xp_id => old_xp} = xp_types} = session} ->
				xp = String.to_integer(xp_amount)
				CharacterSession.changeset(session, %{xp_earned: session.xp_earned + xp, xp_types: Map.put(xp_types, xp_id, old_xp + xp)})
				|> SessionHandler.put()
			{:ok, %CharacterSession{xp_types: xp_types} = session} ->
				xp = String.to_integer(xp_amount)
				CharacterSession.changeset(session, %{xp_earned: session.xp_earned + xp, xp_types: Map.put(xp_types, xp_id, xp)})
				|> SessionHandler.put()
			_ -> nil
		end
	end

	def handle_event({"Death", %{"character_id" => character_id, "attacker_character_id" => attacker_id, "attacker_weapon_id" => weapon_id, "attacker_vehicle_id" => vehicle_id, "is_headshot" => is_headshot}}) do
		# If the weapon is considered an IvI weapon and the attacker is not in a vehicle, is_ivi_kill = true
		is_ivi_kill = Enum.member?(CAIData.ivi_weapon_ids, weapon_id) and vehicle_id == "0"
		is_headshot = String.to_integer(is_headshot)

		case SessionHandler.get(character_id) do
			{:ok, %CharacterSession{} = session} when is_ivi_kill == true ->
				CharacterSession.changeset(session, %{deaths: session.deaths + 1, deaths_ivi: session.deaths_ivi + 1})
				|> SessionHandler.put()
			{:ok, %CharacterSession{} = session} ->
				CharacterSession.changeset(session, %{deaths: session.deaths + 1})
				|> SessionHandler.put()
			_ -> nil
		end
		case SessionHandler.get(attacker_id) do
			{:ok, %CharacterSession{} = session} when is_ivi_kill == true and is_headshot == 1 ->
				CharacterSession.changeset(session, %{kills: session.kills + 1, kills_hs: session.kills_hs + is_headshot, kills_ivi: session.kills_ivi + 1, kills_hs_ivi: session.kills_hs_ivi + (is_ivi_kill && 1 || 0)})
				|> SessionHandler.put()
			{:ok, %CharacterSession{} = session} when is_ivi_kill == true ->
				CharacterSession.changeset(session, %{kills: session.kills + 1, kills_ivi: session.kills_ivi + 1})
				|> SessionHandler.put()
			{:ok, %CharacterSession{} = session} when is_headshot == 1 ->
				CharacterSession.changeset(session, %{kills: session.kills + 1, kills_hs: session.kills_hs + is_headshot})
				|> SessionHandler.put()
			{:ok, %CharacterSession{} = session} ->
				CharacterSession.changeset(session, %{kills: session.kills + 1})
				|> SessionHandler.put()
			_ -> nil
		end
	end

	def handle_event({"PlayerLogin", %{"character_id" => character_id, "timestamp" => timestamp}}) do
		char_query = Query.new(collection: "character")
		|> term("character_id", character_id)
		|> show(["character_id", "faction_id", "name"])
		|> join(Join.new(collection: "characters_weapon_stat")
			|> list(true)
			|> inject_at("weapon_shot_stats")
			|> show(["stat_name", "item_id", "vehicle_id", "value"])
			|> term("stat_name", ["weapon_hit_count", "weapon_fire_count"]) |> term("vehicle_id", "0") |> term("item_id", "0", :not)
			|> join(Join.new(collection: "item")
				|> inject_at("weapon")
				|> outer(false)
				|> show(["name.en", "item_category_id"])
				|> term("item_category_id", ["3", "5", "6", "7", "8", "12", "19", "24", "100", "102"])
			)
		)
		case PS2.API.send_query(char_query) do
			{:ok, %{"character_list" => [%{"name" => %{"first" => name}, "faction_id" => faction_id, "weapon_shot_stats" => stat_map}]}} ->
				# Count weapon_shot_stats
				{fire_count, hit_count} = Enum.reduce(stat_map, {0, 0}, fn
					(%{"stat_name" => "weapon_fire_count", "value" => val}, {fire_count, hit_count}) -> {fire_count + String.to_integer(val), hit_count}
					(%{"stat_name" => "weapon_hit_count", "value" => val}, {fire_count, hit_count}) -> {fire_count, hit_count + String.to_integer(val)}
					(_, {fire_count, hit_count}) -> {fire_count, hit_count}
				end)
				params = %{"character_id" => character_id, "name" => name, "faction_id" => faction_id, "login_timestamp" => timestamp, "shots_fired" => fire_count, "shots_hit" => hit_count}
				CharacterSession.changeset(%CharacterSession{}, params) |> SessionHandler.put()
			{:error, error} -> Logger.error(inspect(error))
			_ -> nil
		end
	end

	def handle_event({"PlayerLogout", %{"character_id" => character_id, "timestamp" => timestamp}}) do
		SessionHandler.close(character_id, timestamp)
	end

	def handle_event({"VehicleDestroy", %{"attacker_vehicle_id" => "0"}}), do: nil
	def handle_event({"VehicleDestroy", %{"character_id" => character_id, "attacker_character_id" => attacker_id, "attacker_vehicle_id" => attacker_vehicle_id}}) do
		with {:ok, vehicle} <- Map.fetch(CAIData.vehicle_info, attacker_vehicle_id) do
			case SessionHandler.get(character_id) do
				{:ok, %CharacterSession{vehicles_lost: vehicles_lost} = session} ->
					amount = Map.get(session.vehicles_lost, vehicle["name"], 0)
					CharacterSession.changeset(session, %{vehicles_lost: Map.put(vehicles_lost, vehicle["name"], amount + 1), nanites_lost: session.nanites_lost + String.to_integer(vehicle["cost"]), vehicle_deaths: session.vehicle_deaths + 1})
					|> SessionHandler.put()
				_ -> nil
			end
			case SessionHandler.get(attacker_id) do
				{:ok, %CharacterSession{vehicles_destroyed: vehicles_destroyed} = session} when attacker_id != character_id ->
					amount = Map.get(session.vehicles_destroyed, vehicle["name"], 0)
					CharacterSession.changeset(session, %{vehicles_destroyed: Map.put(vehicles_destroyed, vehicle["name"], amount + 1), nanites_destroyed: session.nanites_destroyed + String.to_integer(vehicle["cost"]), vehicle_kills: session.vehicle_kills + 1})
					|> SessionHandler.put()
				_ -> nil
			end
		end
	end

	def handle_event({"PlayerFacilityCapture", %{"character_id" => character_id}}) do
		case SessionHandler.get(character_id) do
			{:ok, %CharacterSession{} = session} ->
				CharacterSession.changeset(session, %{base_captures: session.base_captures + 1})
				|> SessionHandler.put()
			_ -> nil
		end
	end

	def handle_event({"PlayerFacilityDefend", %{"character_id" => character_id}}) do
		case SessionHandler.get(character_id) do
			{:ok, %CharacterSession{} = session} ->
				CharacterSession.changeset(session, %{base_defends: session.base_defends + 1})
				|> SessionHandler.put()
			_ -> nil
		end
	end

	# def handle_event({"FacilityControl", payload}), do: nil
	# def handle_event({"ItemAdded", payload}), do: nil
	# def handle_event({"SkillAdded", payload}), do: nil
	# def handle_event({"AchievementEarned", payload}), do: nil
	def handle_event({"BattleRankUp", %{"character_id" => character_id, "battle_rank" => br}}) do
		case SessionHandler.get(character_id) do
			{:ok, %CharacterSession{} = session} ->
				CharacterSession.changeset(session, %{br_ups: [br | session.br_ups]})
				|> SessionHandler.put()
			_ -> nil
		end
	end

	def handle_event({"MetagameEvent", %{"metagame_event_id" => event_id, "metagame_event_state" => event_state}}) do
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
