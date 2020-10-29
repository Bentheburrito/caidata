defmodule CAIData.SessionHandler do
	use GenServer
	require Logger

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

	def put(%Changeset{} = changeset) do
		if changeset.valid? do
			session = Changeset.apply_changes(changeset)
			GenServer.call(__MODULE__, {:put, session})
		else
			{:errors, changeset.errors}
		end
	end

	def close(character_id, logout_timestamp), do: GenServer.cast(__MODULE__, {:close, character_id, logout_timestamp})

 	# Server
	def init(state) do
		{:ok, state}
	end

	def handle_call({:get, character_id}, _from, session_map) do
		case Map.fetch(session_map, character_id) do
			{:ok, session} -> {:reply, {:ok, session}, session_map}
			:error -> {:reply, :none, session_map}
		end
	end

	def handle_call({:put, session}, _from, session_map) do
		{:reply, :ok, Map.put(session_map, session.character_id, session)}
	end

	def handle_cast({:close, character_id, logout_timestamp}, session_map) do
		with {:ok, session} <- Map.fetch(session_map, character_id),
			changeset <- CharacterSession.changeset(session, %{logout_timestamp: logout_timestamp}),
			{:ok, %CharacterSession{character_id: id}} <- Repo.insert(changeset) do
				Logger.debug("Saved session to db: #{id}")
			else
				:error -> Logger.debug("Can't close session [doesn't exist]: #{character_id}")
				{:error, changeset} -> Logger.error("Could not save session to db: #{inspect(changeset.errors)}")
		end
		{:noreply, Map.delete(session_map, character_id)}
	end

	defp fetch_new_sessions(state) do

	end
end
