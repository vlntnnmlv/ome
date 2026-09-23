return {
	name = "root",
	rect = { 0, 0, 1080, 720 },
	children = {
		{
			name = "img",
			kind = "image",
			rect = { 490, 310, 100, 100 },
			atlas = "ui_atlas",
			sprite = "panel",
			slice = { 8, 8, 8, 8 },
			color = { 255, 255, 255, 255 },
		},
		{
			name = "label",
			kind = "text",
			rect = { 100, 100, 500, 100 },
			text = "hello from lua",
			font = "iosevka",
			size = 32,
			color = { 0, 0, 255, 255 },
		},
	},
}
