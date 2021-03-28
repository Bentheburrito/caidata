defmodule CAIData do
	import Ecto.Query

	@ivi_weapon_ids Jason.decode!(File.read!("./lib/static_data/ivi_weapon_ids.json"))
	@vehicle_info Jason.decode!(File.read!("./lib/static_data/vehicle_info.json"))
	@experience_info Jason.decode!(File.read!("./lib/static_data/experience_info.json"))
	@event_info Jason.decode!(File.read!("./lib/static_data/event_info.json"))
	@weapon_info Jason.decode!(File.read!("./lib/static_data/weapon_info.json"))
	@zone_info %{
		"2" => "Indar",
		"4" => "Hossin",
		"6" => "Amerish",
		"8" => "Esamir",
		# Custom IDs assigned for events. The API really generates dynamic IDs for the following.
		"60" => "Koltyr",
		"61" => "Desolation"
	}
	@world_info %{
    "1" => "Connery",
    "10" => "Miller",
    "13" => "Cobalt",
    "17" => "Emerald",
    "19" => "Jaeger",
    "40" => "Soltech",
  }
	@faction_info %{
		"0" => {"No Faction", 0x575757, "https://i.imgur.com/9nHbnUh.jpg"},
		"1" => {"Vanu Sovereignty", 0xb035f2, "https://bit.ly/2RCsHXs"},
		"2" => {"New Conglomerate", 0x2a94f7, "https://bit.ly/2AOZJJB"},
		"3" => {"Terran Republic", 0xe52d2d, "https://bit.ly/2Mm6wij"},
		"4" => {"Nanite Systems", 0xe5e5e5, "https://i.imgur.com/9nHbnUh.jpg"}
	}

	def ivi_weapon_ids, do: @ivi_weapon_ids
	def vehicle_info, do: @vehicle_info
	def experience_info, do: @experience_info
	def event_info, do: @event_info
	def weapon_info, do: @weapon_info
	def zone_info, do: @zone_info
	def world_info, do: @world_info
	def faction_info, do: @faction_info

	def get_session(character_id) do
		CAIData.Repo.one(from s in CAIData.CharacterSession, select: s, where: ilike(s.character_id, ^character_id), limit: 1)
	end

	def get_session_by_name(character_name) do
		CAIData.Repo.one(from s in CAIData.CharacterSession, select: s, where: ilike(s.name, ^character_name), limit: 1)
	end

	def get_all_sessions(character_id) do
		CAIData.Repo.all(from s in CAIData.CharacterSession, select: s, where: ilike(s.character_id, ^character_id))
	end

	def get_active_session(character_id) do
		CAIData.SessionHandler.get(character_id)
	end
end
