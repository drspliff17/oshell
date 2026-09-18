package main

import "core:fmt"

Media_Widget :: struct {
	rect:     Rect,
	bg_col:   Col,
	text_col: Col,
	size:     FT_UInt,
}

draw_media_widget :: proc(layer: ^Layer, widget: Media_Widget) {
	media := &layer.media

	if !media_visible(media) do return

	title := media_get_title(media)
	if title == "" do return

	artist := media_get_artist(media)

	text_buf: [1536]u8
	text := title

	if artist != "" do text = fmt.bprintf(text_buf[:], "%s - %s", artist, title)

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
	metrics := measure_text(layer, text, widget.size)
	text_height := metrics.ascent + metrics.descent
	baseline_y := content.y + (content.height - text_height) * 0.5 + metrics.ascent

	// Fits normally.
	if metrics.width <= content.width {
		media.scroll_active = false
		media.scroll_offset = 0
		media.scroll_max = 0

		text_x := content.x + (content.width - metrics.width) * 0.5
		draw_text(layer, text, Vec2{text_x, baseline_y}, widget.text_col, widget.size)
		return
	}

	// Infinite marquee.
	media.scroll_active = true
	media.scroll_max = metrics.width + MEDIA_SCROLL_GAP

	if media.scroll_offset >= media.scroll_max do media.scroll_offset = 0

	scissor_x := i32(content.x)
	scissor_y := i32(f32(layer.height) - (content.y + content.height))
	scissor_width := i32(content.width)
	scissor_height := i32(content.height)

	glEnable(GL_SCISSOR_TEST)
	glScissor(scissor_x, scissor_y, scissor_width, scissor_height)

	first_x := content.x - media.scroll_offset
	second_x := first_x + media.scroll_max

	draw_text(layer, text, Vec2{first_x, baseline_y}, widget.text_col, widget.size)
	draw_text(layer, text, Vec2{second_x, baseline_y}, widget.text_col, widget.size)

	glDisable(GL_SCISSOR_TEST)
}
