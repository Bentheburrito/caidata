defmodule CAIData.CharacterSession do
  use Ecto.Schema
  import Ecto.Changeset

  schema "character_sessions" do
    field :character_id, :string
    field :faction_id, :integer
    field :name, :string
    field :kills, :integer, default: 0
    field :kills_hs, :integer, default: 0
    field :kills_ivi, :integer, default: 0
    field :kills_hs_ivi, :integer, default: 0
    field :deaths, :integer, default: 0
    field :deaths_ivi, :integer, default: 0
    field :shots_fired, :integer, default: 0
    field :shots_hit, :integer, default: 0
    field :vehicle_kills, :integer, default: 0
    field :vehicle_deaths, :integer, default: 0
    field :vehicle_bails, :integer, default: 0
    # Like %{"vehicle_name" => amount_killed}
    field :vehicles_destroyed, {:map, :integer}, default: %{}
    field :vehicles_lost, {:map, :integer}, default: %{}
    field :nanites_destroyed, :integer, default: 0
    field :nanites_lost, :integer, default: 0
    field :xp_earned, :integer, default: 0
    # Like %{"xp_type_name" => amount_earned}
    field :xp_types, {:map, :integer}, default: %{}
    field :br_ups, {:array, :string}, default: []
    field :base_captures, :integer, default: 0
    field :base_defends, :integer, default: 0
    field :login_timestamp, :integer, default: 0
    field :logout_timestamp, :integer, default: 0
    field :archived, :boolean, default: false
  end

  def changeset(session, params \\ %{}) do
    field_list = __MODULE__.__schema__(:fields) |> List.delete(:id)

    session
    |> cast(params, field_list)
    |> validate_required(
      field_list
      |> List.delete(:logout_timestamp)
      |> List.delete(:name)
      |> List.delete(:faction_id)
    )
    |> validate_length(:character_id, max: 19)
  end
end
