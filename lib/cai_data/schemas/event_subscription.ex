defmodule CAIData.EventSubscription do
  use Ecto.Schema
  import Ecto.Changeset

  schema "event_subscriptions" do
    field(:user_id, :string)
    field(:event_ids, {:array, :integer})
    field(:notify_bound_lower, :utc_datetime)
    field(:notify_bound_upper, :utc_datetime)
  end

  def changeset(subscription, params \\ %{}) do
    subscription
    |> cast(params, [:user_id, :event_ids, :notify_bound_lower, :notify_bound_upper])
    |> validate_required([:user_id, :event_ids, :notify_bound_lower, :notify_bound_upper])
  end
end
