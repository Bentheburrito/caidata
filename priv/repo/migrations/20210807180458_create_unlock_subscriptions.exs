defmodule CAIData.Repo.Migrations.CreateUnlockSubscriptions do
  use Ecto.Migration

  def change do
    create table(:unlock_subscriptions) do
			add :user_id, :string, size: 18
			add :world_ids, {:array, :integer}
      add :zone_ids, {:array, :integer}
			add :notify_bound_lower, :utc_datetime
			add :notify_bound_upper, :utc_datetime
		end
  end
end
