defmodule Utilities.Map do
	def update_existing(map, key, function) do
		case map do
			%{^key => _val} -> Map.update!(map, key, function)
			_ -> map
		end
	end
end
