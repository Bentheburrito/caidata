defmodule CAIData.CharacterSession do
	use Ecto.Schema
	import Ecto.Changeset

	@field_list [
		:character_id,
		:faction_id,
		:name,
		:kills,
		:kills_hs,
		:kills_ivi,
		:kills_hs_ivi,
		:deaths,
		:deaths_ivi,
		:shots_fired,
		:shots_hit,
		:vehicle_kills,
		:vehicle_deaths,
		:vehicle_bails,
		:vehicles_destroyed,
		:vehicles_lost,
		:nanites_destroyed,
		:nanites_lost,
		:xp_earned,
		:xp_types,
		:br_ups,
		:base_captures,
		:base_defends,
		:login_timestamp,
		:logout_timestamp,
		:archived
	]

  schema "character_sessions" do
    field :character_id, :string
		field :faction_id, :integer
		field :name, :string
		field :kills, :integer, default: 0
		field :kills_hs, :integer, default: 0
		field :kills_ivi, :integer, default: 0
		field :kills_hs_ivi, :integer, default: 0
		field :deaths, :integer, default: 0
		field :deaths_ivi, :integer, default: 0
		field :shots_fired, :integer, default: 0
		field :shots_hit, :integer, default: 0
		field :vehicle_kills, :integer, default: 0
		field :vehicle_deaths, :integer, default: 0
		field :vehicle_bails, :integer, default: 0
		field :vehicles_destroyed, {:map, :integer}, default: %{} # Like %{"vehicle_name" => amount_killed}
		field :vehicles_lost, {:map, :integer}, default: %{}
		field :nanites_destroyed, :integer, default: 0
		field :nanites_lost, :integer, default: 0
		field :xp_earned, :integer, default: 0
		field :xp_types, {:map, :integer}, default: %{} # Like %{"xp_type_name" => amount_earned}
		field :br_ups, {:array, :string}, default: []
		field :base_captures, :integer, default: 0
		field :base_defends, :integer, default: 0
		field :login_timestamp, :integer, default: 0
		field :logout_timestamp, :integer, default: 0
		field :archived, :boolean, default: false
	end

	def changeset(session, params \\ %{}) do
		session
		|> cast(params, @field_list)
		|> validate_required(@field_list |> List.delete(:logout_timestamp) |> List.delete(:name) |> List.delete(:faction_id))
		|> validate_length(:character_id, max: 19)
	end
end
