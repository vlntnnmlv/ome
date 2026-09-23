package omeui

BindTarget :: enum {
	Text,
	Color,
}

Binding :: struct {
	target: BindTarget,
	path:   string,
}
