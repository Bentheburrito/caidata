defmodule CAIData.PublicRole do
  use Ecto.Schema
  import Ecto.Changeset

  schema "public_roles" do
    field :role_id, :string
  end

  def changeset(public_role, params \\ %{}) do
    public_role
    |> cast(params, [:role_id])
    |> validate_required([:role_id])
    |> validate_length(:role_id, max: 18)
  end
end
