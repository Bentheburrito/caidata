defmodule CAIData.Repo.Migrations.CreateCharacterSessions do
  use Ecto.Migration

  def change do
		create table(:character_sessions) do
			add :character_id, :string, size: 19
			add :faction_id, :integer
			add :name, :string, size: 70
			add :kills, :integer
			add :kills_hs, :integer
			add :kills_ivi, :integer
			add :kills_hs_ivi, :integer
			add :deaths, :integer
			add :deaths_ivi, :integer
			add :shots_fired, :integer
			add :shots_hit, :integer
			add :vehicle_kills, :integer
			add :vehicle_deaths, :integer
			add :vehicle_bails, :integer
			add :vehicles_destroyed, {:map, :integer} # Like %{"vehicle_name" => amount_killed}
			add :vehicles_lost, {:map, :integer}
			add :xp_earned, :integer
			add :xp_types, {:map, :integer} # Like %{"xp_type_name" => amount_earned}
			add :base_captures, :integer
			add :base_defends, :integer
			add :login_timestamp, :integer
			add :logout_timestamp, :integer
			add :archived, :boolean
		end
  end
end
