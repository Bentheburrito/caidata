defmodule CAIData.GuildInfo do
	use Ecto.Schema
	import Ecto.Changeset

  schema "guild_info" do
    field :guild_id, :string
    field :status_message_id, :string
	end

	def changeset(guild_info, params \\ %{}) do
		guild_info
		|> cast(params, [:guild_id, :status_message_id])
		|> validate_required([:guild_id, :status_message_id])
		|> validate_length(:guild_id, max: 18)
		|> validate_length(:status_message_id, max: 18)
	end
end
