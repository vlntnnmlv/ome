local function create_bricks(w, h)
	local bricks = {}
	for i = 0, w * h do
		bricks[i] = { alive = true }
	end
	bricks.width = w
	bricks.height = h
	return bricks
end

local model = { x = 100, y = 500, vx = 1, vy = 1, bricks = create_bricks(10, 5) }

return {
	model = model,
	computed = {
	},
	actions = {
	},
	update = function(m, dt)
		w, h = ome.screen()
		m.x = m.x + m.vx
		m.y = m.y + m.vy
		if m.x >= w or m.x <= 0 then
			m.vx = -1 * m.vx
		end
		if m.y >= h or m.y <= 0 then
			m.vy = -1 * m.vy
		end
	end,

	draw = function(m)
		local sw, _ = ome.screen()
		local grid = m.bricks
		local area_h = 300
		local spacing = 5
		local bw = (sw - spacing * (grid.width + 1)) / grid.width
		local bh = (area_h - spacing * (grid.height + 1)) / grid.height

		for i = 0, grid.width * grid.height - 1 do
			if grid[i].alive then
				local col = i % grid.width
				local row = i // grid.width
				local x = spacing + col * (bw + spacing)
				local y = spacing + row * (bh + spacing)
				ome.sprite("ui_atlas", "panel", x, y, bw, bh, { 255, 255, 255 })
			end
		end

		ome.rect(m.x - 5, m.y - 5, 10, 10, { 255, 80, 80 })
	end,
}
