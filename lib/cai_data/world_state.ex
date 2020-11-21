defmodule CAIData.WorldState do
	use Agent

	# tuple value at index faction_id is that faction's pop. (0 is global population)
	# world_id => {global_pop, vs_pop, nc_pop, tr_pop, ns_pop}
	@initial_state %{
		"1" => {0, 0, 0, 0, 0},
		"10" => {0, 0, 0, 0, 0},
		"13" => {0, 0, 0, 0, 0},
		"17" => {0, 0, 0, 0, 0},
		"19" => {0, 0, 0, 0, 0},
		"40" => {0, 0, 0, 0, 0},
	}

	def start_link(_init) do
    Agent.start_link(fn -> @initial_state end, name: __MODULE__)
  end

	def add_world_pop(world_id, faction_id, pop) when is_binary(faction_id), do: add_world_pop(world_id, String.to_integer(faction_id), pop)
	def add_world_pop(world_id, faction_id, pop) when is_integer(faction_id) and is_integer(pop) do
		Agent.update(__MODULE__, &Map.update!(&1, world_id,
		fn state ->
			new_faction_pop = elem(state, faction_id) + pop
			new_global_pop = elem(state, 0) + pop
			put_elem(state, faction_id, new_faction_pop) |> put_elem(0, new_global_pop)
		end))
	end

	def get_world_pop(world_id, faction_id) when is_binary(faction_id), do: get_world_pop(world_id, String.to_integer(faction_id))
	def get_world_pop(world_id, faction_id), do: Agent.get(__MODULE__, &Map.get(&1, world_id) |> elem(faction_id))
	def get_world_pop(world_id), do: Agent.get(__MODULE__, &Map.get(&1, world_id))
end
