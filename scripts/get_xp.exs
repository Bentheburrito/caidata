import PS2.API.QueryBuilder
alias PS2.API.Query

{:ok, %{"experience_list" => xp_list}} = PS2.API.send_query(Query.new(collection: "experience") |> limit(5000))

new_xp_map = for xp_map <- xp_list, into: %{} do
	Map.pop!(xp_map, "experience_id")
end |> Jason.encode!(pretty: true)

File.write("./lib/static_data/experience_info.json", new_xp_map)
