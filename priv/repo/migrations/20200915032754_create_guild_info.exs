defmodule CAIData.Repo.Migrations.CreateGuildInfo do
  use Ecto.Migration

  def change do
		create table(:guild_info) do
			add :guild_id, :string, size: 18
			add :status_message_id, :string, size: 18
		end
  end
end
