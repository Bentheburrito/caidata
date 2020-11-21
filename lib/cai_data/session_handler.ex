defmodule CAIData.SessionHandler do
	use GenServer
	require Logger

	import PS2.API.QueryBuilder

	alias PS2.API.{Query, Join}
	alias Ecto.Changeset
	alias CAIData.CharacterSession
	alias CAIData.Repo

	# Client
	def start_link(init_state) do
		GenServer.start_link(__MODULE__, init_state, name: __MODULE__)
	end

	def get(character_id) do
		GenServer.call(__MODULE__, {:get, character_id})
	end

	def put(character_id, login_timestamp) do
		changeset = CharacterSession.changeset(%CharacterSession{}, %{character_id: character_id, login_timestamp: login_timestamp})
		if changeset.valid? do
			session = Changeset.apply_changes(changeset)
			GenServer.call(__MODULE__, {:put, session})
		else
			{:errors, changeset.errors}
		end
	end

	def update(%Changeset{} = changeset) do
		if changeset.valid? do
			session = Changeset.apply_changes(changeset)
			GenServer.call(__MODULE__, {:update, session})
		else
			{:errors, changeset.errors}
		end
	end

	def close(character_id, logout_timestamp) do
		GenServer.cast(__MODULE__, {:close, character_id, logout_timestamp})
	end

 	# Server
	def init(state) do
		schedule_work()
		{:ok, state}
	end

	def handle_call({:get, character_id}, _from, {session_map, pending_ids}) do
		case Map.fetch(session_map, character_id) do
			{:ok, session} -> {:reply, {:ok, session}, {session_map, pending_ids}}
			:error -> {:reply, :none, {session_map, pending_ids}}
		end
	end

	def handle_call({:put, %CharacterSession{character_id: character_id} = session}, _from, {session_map, pending_ids}) do
		{:reply, :ok, {Map.put(session_map, character_id, session), [character_id | pending_ids]}}
	end

	def handle_call({:update, %CharacterSession{character_id: character_id} = session}, _from, {session_map, pending_ids}) do
		{:reply, :ok, {Map.put(session_map, character_id, session), pending_ids}}
	end

	def handle_cast({:close, character_id, logout_timestamp}, {session_map, pending_ids}) do
		with {:ok, %CharacterSession{xp_earned: xp} = session} when xp > 0 <- Map.fetch(session_map, character_id),
			changeset <- CharacterSession.changeset(session, %{logout_timestamp: logout_timestamp}),
			{:ok, %CharacterSession{character_id: id}} <- Repo.insert(changeset) do
				Logger.debug("Saved session to db: #{id}")
			else
				{:ok, %CharacterSession{}} -> Logger.debug("Not saving session with 0 xp: #{character_id}")
				:error -> Logger.debug("Can't close session [doesn't exist]: #{character_id}")
				{:error, changeset} -> Logger.error("Could not save session to db: #{inspect(changeset.errors)}")
		end
		{:noreply, {Map.delete(session_map, character_id), List.delete(pending_ids, character_id)}}
	end

	def handle_info({:fetch_new_sessions, :start}, {_session_map, queue} = state) when queue == [] do
		schedule_work()
		{:noreply, state}
	end
	def handle_info({:fetch_new_sessions, :start}, {session_map, pending_ids}) do
		Task.start(fn ->
			result = fetch_char_list(pending_ids)
			send(__MODULE__, {:fetch_new_sessions, :end, result})
		end)
		{:noreply, {session_map, []}}
	end
	def handle_info({:fetch_new_sessions, :end, {char_list, remaining_pending_ids}}, {session_map, pending_ids}) do
		new_session_map = char_list_to_sessions(char_list, session_map)
		schedule_work()
		{:noreply, {new_session_map, pending_ids ++ remaining_pending_ids}}
	end

	# Still need to check if some character's are missing (in the case of new characters)
	defp fetch_char_list(character_ids) do
		char_query = Query.new(collection: "character")
			|> term("character_id", Enum.join(character_ids, ","))
			|> show(["character_id", "faction_id", "name"])
			|> join(Join.new(collection: "characters_world")
				|> inject_at("world")
				|> show("world_id")
			)
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
			{:ok, %{"character_list" => char_list}} ->
				{char_list, []}
			{:error, error} -> # Likely a timeout or other random error from the API.
				Logger.error(inspect(error))
				{[], character_ids}
			e -> # Fatal error in query, so just discard the character_ids that cause it.
				Logger.error(inspect(e))
				{[], []}
		end
	end

	defp char_list_to_sessions([], session_map), do: session_map
	defp char_list_to_sessions(char_list, session_map) do
		Enum.reduce(char_list, session_map, fn
			(%{"character_id" => character_id, "name" => %{"first" => name}, "faction_id" => faction_id, "world" => %{"world_id" => world_id}} = char, sessions) when is_map_key(sessions, character_id) ->
				# Count weapon_shot_stats
				{fire_count, hit_count} = count_weapon_stats(Map.get(char, "weapon_shot_stats", %{}))

				params = %{"name" => name, "faction_id" => faction_id, "shots_fired" => fire_count, "shots_hit" => hit_count}
				changeset = CharacterSession.changeset(Map.get(session_map, character_id), params)
				if changeset.valid? do
					CAIData.WorldState.add_world_pop(world_id, faction_id, 1)
					session = Changeset.apply_changes(changeset)
					Map.put(sessions, character_id, session)
				else
					sessions
				end
			(_, sessions) ->
				sessions
		end)
	end

	defp count_weapon_stats(stat_map) when stat_map == %{}, do: {0, 0}
	defp count_weapon_stats(stat_map) do
		Enum.reduce(stat_map, {0, 0}, fn
			(%{"stat_name" => "weapon_fire_count", "value" => val}, {fire_count, hit_count}) -> {fire_count + String.to_integer(val), hit_count}
			(%{"stat_name" => "weapon_hit_count", "value" => val}, {fire_count, hit_count}) -> {fire_count, hit_count + String.to_integer(val)}
			(_, {fire_count, hit_count}) -> {fire_count, hit_count}
		end)
	end

	defp schedule_work() do
		Process.send_after(self(), {:fetch_new_sessions, :start}, 15 * 1000) # Every 15 seconds.
	end
end
