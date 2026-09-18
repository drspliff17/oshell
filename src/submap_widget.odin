package main

Submap_Widget :: struct {
	rect:      Rect,
	bg_col:    Col,
	text_col:  Col,
	text_size: FT_UInt,
}

draw_submap :: proc(layer: ^Layer, widget: Submap_Widget) {
	text := hyprland_get_submap(&layer.hypr.state)
	if text == "" do return

	// Background
	glUseProgram(layer.program)

	glUniform2f(layer.resolution_location, f32(layer.width), f32(layer.height))
	glBindBuffer(GL_ARRAY_BUFFER, layer.vbo)

	position_location := u32(layer.rect_vertex_position_location)

	glEnableVertexAttribArray(position_location)
	glVertexAttribPointer(position_location, 2, GL_FLOAT, GL_FALSE, 2 * size_of(f32), nil)

	draw_rect(layer, widget.rect, widget.bg_col)

	// Text
	glUseProgram(layer.text_program)

	glUniform2f(layer.text_resolution_location, f32(layer.width), f32(layer.height))
	glBindBuffer(GL_ARRAY_BUFFER, layer.text_vbo)

	glEnableVertexAttribArray(u32(layer.text_position_location))
	glEnableVertexAttribArray(u32(layer.text_uv_location))

	glVertexAttribPointer(
		u32(layer.text_position_location),
		2,
		GL_FLOAT,
		GL_FALSE,
		4 * size_of(f32),
		nil,
	)

	glVertexAttribPointer(
		u32(layer.text_uv_location),
		2,
		GL_FLOAT,
		GL_FALSE,
		4 * size_of(f32),
		cast(rawptr)(uintptr(2 * size_of(f32))),
	)

	content := rect_content(widget.rect)

	metrics := measure_text(layer, text, widget.text_size)
	text_height := metrics.ascent + metrics.descent
	text_x := content.x + (content.width - metrics.width) * 0.5
	baseline_y := content.y + (content.height - text_height) * 0.5 + metrics.ascent

	draw_text(layer, text, Vec2{text_x, baseline_y}, widget.text_col, widget.text_size)
}
