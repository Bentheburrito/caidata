defmodule CAIData.Repo.Migrations.CreateTimeZones do
  use Ecto.Migration

  def change do
		create table(:time_zones) do
			add :user_id, :string, size: 18
			add :time_zone, :string
			add :is_public, :boolean
		end
  end
end
