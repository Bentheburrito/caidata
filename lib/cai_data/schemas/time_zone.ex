defmodule CAIData.TimeZone do
  use Ecto.Schema
  import Ecto.Changeset

  schema "time_zones" do
    field :user_id, :string
    field :time_zone, :string
    field :is_public, :boolean, default: false
  end

  def changeset(time_zone, params \\ %{}) do
    time_zone
    |> cast(params, [:user_id, :time_zone, :is_public])
    |> validate_required([:role_id, :time_zone])
  end
end
