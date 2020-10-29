defmodule CAIData.Repo.Migrations.UpdateCharacterSessions do
  use Ecto.Migration

  def change do
		alter table(:character_sessions) do
			add :nanites_destroyed, :integer
			add :nanites_lost, :integer
			add :br_ups, {:array, :string}
		end
  end
end
