package main

import "core:fmt"
import "core:time"

Clock_Widget :: struct {
	rect:     Rect,
	bg_col:   Col,
	text_col: Col,
	size:     FT_UInt,
}

draw_clock :: proc(layer: ^Layer, clock: Clock_Widget) {
	now := time.now()
	hour, minute, _ := time.clock_from_time(now)
	buf: [16]u8

	text := fmt.bprintf(buf[:], "%02d:%02d", hour + 1, minute)

	rect := clock.rect
	rect.padding = GetPadding(8, .VERTICAL)

	// Background

	glUseProgram(layer.program)

	glUniform2f(layer.resolution_location, f32(layer.width), f32(layer.height))
	glBindBuffer(GL_ARRAY_BUFFER, layer.vbo)

	position_location := u32(layer.rect_vertex_position_location)

	glEnableVertexAttribArray(position_location)
	glVertexAttribPointer(position_location, 2, GL_FLOAT, GL_FALSE, 2 * size_of(f32), nil)

	draw_rect(layer, rect, clock.bg_col)

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

	content := rect_content(rect)

	metrics := measure_text(layer, text, clock.size)
	text_height := metrics.ascent + metrics.descent

	text_x := content.x + (content.width - metrics.width) * 0.5
	baseline_y := content.y + (content.height - text_height) * 0.5 + metrics.ascent

	draw_text(layer, text, Vec2{text_x, baseline_y}, clock.text_col, clock.size)
}
