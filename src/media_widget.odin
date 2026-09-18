package main

Media_Widget :: struct {
	rect:     Rect,
	bg_col:   Col,
	text_col: Col,
	size:     FT_UInt,
}

draw_media_widget :: proc(layer: ^Layer, widget: Media_Widget) {
	media := &layer.media

	if !media_visible(media) do return

	text := media_get_title(media)
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

	metrics := measure_text(layer, text, widget.size)

	text_height := metrics.ascent + metrics.descent

	baseline_y := content.y + (content.height - text_height) * 0.5 + metrics.ascent

	if metrics.width <= content.width {
		text_x := content.x + (content.width - metrics.width) * 0.5
		draw_text(layer, text, Vec2{text_x, baseline_y}, widget.text_col, widget.size)
		return
	}

	ellipsis := "..."
	ellipsis_metrics := measure_text(layer, ellipsis, widget.size)
	available_width := max(0, content.width - ellipsis_metrics.width)
	prefix_width: f32

	for character in text {
		glyph, ok := cache_glyph(layer, character, widget.size)
		if !ok do continue

		advance := f32(glyph.advance)

		if prefix_width + advance > available_width do break
		prefix_width += advance
	}

	total_width := prefix_width + ellipsis_metrics.width
	text_x := content.x + (content.width - total_width) * 0.5

	glActiveTexture(GL_TEXTURE0)
	glBindTexture(GL_TEXTURE_2D, layer.font.texture)

	glUniform1i(layer.text_texture_location, 0)
	glUniform4f(
		layer.text_color_location,
		widget.text_col.r,
		widget.text_col.g,
		widget.text_col.b,
		widget.text_col.a,
	)

	pen_x := text_x
	drawn_width: f32

	for character in text {
		glyph, ok := cache_glyph(layer, character, widget.size)

		if !ok do continue

		advance := f32(glyph.advance)
		if drawn_width + advance > available_width do break
		pen_x = draw_glyph(layer, character, widget.size, pen_x, baseline_y)
		drawn_width += advance
	}

	draw_text(layer, ellipsis, Vec2{pen_x, baseline_y}, widget.text_col, widget.size)
}
