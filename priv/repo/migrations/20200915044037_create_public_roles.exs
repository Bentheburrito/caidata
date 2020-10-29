defmodule CAIData.Repo.Migrations.CreatePublicRoles do
  use Ecto.Migration

  def change do
		create table(:public_roles) do
			add :role_id, :string, size: 18
		end
  end
end
