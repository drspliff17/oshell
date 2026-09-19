package main

import "core:fmt"

Volume_Widget :: struct {
	rect:      Rect,
	bg_col:    Col,
	text_col:  Col,
	text_size: FT_UInt,
}

volume_get_text :: proc(volume: ^Volume_State, buffer: []u8) -> string {
	if !volume_available(volume) do return ""
	if volume_is_muted(volume) do return fmt.bprintf(buffer, " %d%%", volume_get_percent(volume))
	return fmt.bprintf(buffer, " %d%%", volume_get_percent(volume))
}

draw_volume :: proc(layer: ^Layer, widget: Volume_Widget) {
	volume := &layer.volume
	if !volume_available(volume) do return

	text_buffer: [64]u8

	text := volume_get_text(volume, text_buffer[:])
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

	text_x := content.x + (content.width - metrics.width) * 0.5
	baseline_y := centered_text_baseline(layer, content, widget.text_size)

	draw_text(layer, text, Vec2{text_x, baseline_y}, widget.text_col, widget.text_size)
}
