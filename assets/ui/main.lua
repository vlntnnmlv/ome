local function create_bricks(w, h)
	local bricks = {}
	for i = 0, w * h do
		bricks[i] = { alive = true }
	end
	bricks.width = w
	bricks.height = h
	return bricks
end

local function create_ball(x, y, w, h, vx, vy)
	return {
		x = x,
		y = y,
		w = w,
		h = h,
		vx = vx,
		vy = vy
	}
end

local function ball_update(ball, dt)
	local w, h = ome.screen()

	ball.x = ball.x + ball.vx * dt
	ball.y = ball.y + ball.vy * dt
	if ball.x >= w or ball.x <= 0 then
		ball.vx = -1 * ball.vx
	end
	if ball.y >= h or ball.y <= 0 then
		ball.vy = -1 * ball.vy
	end
end

local model = {
	ball = create_ball(500, 500, 10, 10, 100, 100),
	bricks = create_bricks(10, 5),
}

return {
	model = model,
	computed = {
	},
	actions = {
	},
	update = function(m, dt)
		ball_update(m.ball, dt)
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

		ome.rect(
			m.ball.x - m.ball.w / 2,
			m.ball.y - m.ball.h / 2,
			m.ball.w,
			m.ball.h,
			{ 255, 80, 80 }
		)
	end,
}
