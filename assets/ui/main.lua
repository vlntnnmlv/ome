local function create_player(x, y)
	return {
		x = x,
		y = y,
	}
end


local model = {
	player = create_player(500, 500)
}

return {
	model = model,
	computed = {
	},
	actions = {
	},
	update = function(m, dt)
		if ome.key_down("w") then
			m.player.y = m.player.y - 1
		end
		if ome.key_down("a") then
			m.player.x = m.player.x - 1
		end
		if ome.key_down("s") then
			m.player.y = m.player.y + 1
		end
		if ome.key_down("d") then
			m.player.x = m.player.x + 1
		end
	end,
	draw = function(m)
		ome.sprite("player_atlas", "jungle_dweller", m.player.x - 25, m.player.y - 25, 50, 50, { 255, 255, 255 })
	end,
}
