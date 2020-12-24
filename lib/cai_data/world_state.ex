defmodule CAIData.WorldState do
	use GenServer

	# Client
	def start_link(_init_state) do
		GenServer.start_link(__MODULE__, {%{}, %{}}, name: __MODULE__)
	end

	def add_population(world_id, faction_id, pop), do: GenServer.cast(__MODULE__, {:add_pop, world_id, faction_id, pop})

	def get_population(world_id, faction_id), do: GenServer.call(__MODULE__, {:get_pop, world_id, faction_id})
	def get_population(world_id), do: GenServer.call(__MODULE__, {:get_pop, world_id})

	def put_bastion(world_id, zone_id, faction_id, outfit_alias), do: GenServer.cast(__MODULE__, {:put_bastion, world_id, zone_id, faction_id, outfit_alias})

	def damage_bastion(world_id, zone_id, npc_id) when is_binary(npc_id), do: GenServer.cast(__MODULE__, {:damage_bastion, world_id, zone_id, String.to_integer(npc_id)})
	def damage_bastion(world_id, zone_id, npc_id), do: GenServer.cast(__MODULE__, {:damage_bastion, world_id, zone_id, npc_id})

	def remove_bastion(world_id, zone_id, faction_id), do: GenServer.cast(__MODULE__, {:remove_bastion, world_id, zone_id, faction_id})

	# Server
	def init(state) do
		{:ok, state}
	end

	def handle_cast({:add_pop, world_id, faction_id, pop}, {population_state, bastion_state}) do
		new_population_state =
			population_state
			|> Map.update({world_id, faction_id}, pop, &(&1 + pop))
			|> Map.update({world_id, 0}, pop, &(&1 + pop))
		{:noreply, {new_population_state, bastion_state}}
	end

	def handle_cast({:put_bastion, world_id, zone_id, faction_id, outfit_alias}, {population_state, bastion_state}) do
		{:noreply, {population_state, Map.put(bastion_state, {world_id, zone_id, faction_id}, %{faction_id: faction_id, health: 8, outfit_alias: outfit_alias, comp_set: []})}}
	end

	def handle_cast({:damage_bastion, world_id, zone_id, npc_id}, {population_state, bastion_state}) do
		relevant_bastions = Enum.filter(bastion_state, fn
			{{^world_id, ^zone_id, _faction_id}, _val} -> true
			_bastion -> false
		end)
		case get_component_bastion(relevant_bastions, npc_id) do
			%{faction_id: faction_id} ->
				new_bastion_state = Utilities.Map.update_existing(bastion_state, {world_id, zone_id, faction_id}, &(%{&1 | health: &1.health - 1, comp_set: [npc_id | &1.comp_set]}))
				{:noreply, {population_state, new_bastion_state}}
			_ -> {:noreply, {population_state, bastion_state}}
		end
	end

	def handle_cast({:remove_bastion, world_id, zone_id, faction_id}, {population_state, bastion_state}) do
		{:noreply, {population_state, Map.delete(bastion_state, {world_id, zone_id, faction_id})}}
	end

	def handle_call({:get_pop, world_id, faction_id}, _from, {population_state, _bastion_state} = state) do
		{:reply, Map.get(population_state, {world_id, faction_id}), state}
	end

	def handle_call({:get_pop, world_id}, _from, {population_state, _bastion_state} = state) do
		{:reply, Map.get(population_state, {world_id, 0}), state}
	end

	defp get_component_bastion([], _npc_id), do: nil
	defp get_component_bastion([bastion], _npc_id), do: bastion[:faction_id]
	defp get_component_bastion(bastion_list, npc_id) do
		Enum.find(bastion_list, fn bastion ->
			with {min_comp, max_comp} <- Enum.min_max(bastion.comp_set, fn -> false end),
						range <- max_comp - min_comp,
						do: npc_id >= min_comp - range and npc_id <= max_comp + range
		end)
	end
end
