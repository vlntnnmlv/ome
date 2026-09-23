local model = { title = "Play", clicks = 0, tint = { 255, 255, 255, 255 } }

return {
	model = model,
	actions = {
		play = function(m)
			m.tint = { 255, 200 - m.clicks * 20, 0, 255 }
			m.clicks = m.clicks + 1
			m.title = "Clicked " .. m.clicks .. " times"
		end,
	},
}
