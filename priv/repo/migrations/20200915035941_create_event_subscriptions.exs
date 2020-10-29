defmodule CAIData.Repo.Migrations.CreateEventSubscriptions do
  use Ecto.Migration

  def change do
		create table(:event_subscriptions) do
			add :user_id, :string, size: 18
			add :event_ids, {:array, :integer}
			add :notify_bound_lower, :utc_datetime
			add :notify_bound_upper, :utc_datetime
		end
  end
end
