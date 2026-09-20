package main

render_notification_layer :: proc(layer: ^Layer) {
	index := notifications_find(&layer.notifications, layer.notification_id)
	if index < 0 do return

	notification := &layer.notifications.items[index]
	summary := notification_get_summary(notification)
	body := notification_get_body(notification)

	if summary == "" && body == "" do return

	font_size := app_get_font_size(layer.app)

	padding_x := f32(NOTIFICATION_PADDING_X)
	padding_y := f32(NOTIFICATION_PADDING_Y)
	text_gap := f32(NOTIFICATION_TEXT_GAP)

	box_rect := Rect {
		x = 0,
		y = 0,
		width = f32(layer.width),
		height = f32(layer.height),
		radius = 12,
		padding = Padding {
			top = padding_y,
			left = padding_x,
			bottom = padding_y,
			right = padding_x,
		},
		border_col = COLOURS.Border_Contrast_Widget,
		border_size = 2,
	}

	// Background
	glUseProgram(layer.program)

	glUniform2f(layer.resolution_location, f32(layer.width), f32(layer.height))
	glBindBuffer(GL_ARRAY_BUFFER, layer.vbo)

	position_location := u32(layer.rect_vertex_position_location)

	glEnableVertexAttribArray(position_location)
	glVertexAttribPointer(position_location, 2, GL_FLOAT, GL_FALSE, 2 * size_of(f32), nil)

	draw_rect(layer, box_rect, COLOURS.Widget)

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

	content := rect_content(box_rect)

	summary_buffer: [NOTIFICATION_SUMMARY_CAPACITY]u8
	body_buffer: [NOTIFICATION_BODY_CAPACITY]u8

	display_summary := truncate_text(layer, summary, font_size, content.width, summary_buffer[:])
	display_body := ""

	if body != "" do display_body = truncate_text(layer, body, font_size, content.width, body_buffer[:])

	line_metrics := measure_text(layer, "Hg", font_size)
	line_height := line_metrics.ascent + line_metrics.descent

	if display_body == "" {
		baseline := centered_text_baseline(layer, content, font_size)
		draw_text(layer, display_summary, Vec2{content.x, baseline}, COLOURS.Font, font_size)
		return
	}

	total_height := line_height * 2 + text_gap
	text_y := content.y + (content.height - total_height) * 0.5
	summary_baseline := text_y + line_metrics.ascent

	draw_text(layer, display_summary, Vec2{content.x, summary_baseline}, COLOURS.Font, font_size)

	body_baseline := text_y + line_height + text_gap + line_metrics.ascent
	draw_text(layer, display_body, Vec2{content.x, body_baseline}, COLOURS.Font_Dim, font_size)
}
