defmodule CAIData.UnlockSubscription do
  use Ecto.Schema
  import Ecto.Changeset

  schema "unlock_subscriptions" do
    field :user_id, :string
    field :world_ids, {:array, :integer}
    field :zone_ids, {:array, :integer}
    field :notify_bound_lower, :utc_datetime
    field :notify_bound_upper, :utc_datetime
  end

  def changeset(subscription, params \\ %{}) do
    subscription
    |> cast(params, [:user_id, :world_ids, :zone_ids, :notify_bound_lower, :notify_bound_upper])
    |> validate_required([
      :user_id,
      :world_ids,
      :zone_ids,
      :notify_bound_lower,
      :notify_bound_upper
    ])
  end
end
