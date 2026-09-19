package main

import "core:fmt"

Workspace_Widget :: struct {
	rect:              Rect,
	size:              f32,
	gap:               f32,
	radius:            f32,
	border_size:       f32,
	border_col:        Col,
	active_border_col: Col,
	col:               Col,
	active_col:        Col,
	text_col:          Col,
	active_text_col:   Col,
	text_size:         FT_UInt,
}

draw_workspaces :: proc(layer: ^Layer, widget: Workspace_Widget) {
	state := &layer.hypr.state
	count := len(state.workspaces)
	if count == 0 do return

	total_width := f32(count) * widget.size + f32(count - 1) * widget.gap

	start_x := widget.rect.x + (widget.rect.width - total_width) * 0.5
	y := widget.rect.y + (widget.rect.height - widget.size) * 0.5

	// Rectangles
	glUseProgram(layer.program)
	glUniform2f(layer.resolution_location, f32(layer.width), f32(layer.height))
	glBindBuffer(GL_ARRAY_BUFFER, layer.vbo)

	position_location := u32(layer.rect_vertex_position_location)

	glEnableVertexAttribArray(position_location)
	glVertexAttribPointer(position_location, 2, GL_FLOAT, GL_FALSE, 2 * size_of(f32), nil)

	for workspace, i in state.workspaces {
		x := start_x + f32(i) * (widget.size + widget.gap)
		draw_rect(
			layer,
			Rect {
				x = x,
				y = y,
				width = widget.size,
				height = widget.size,
				radius = widget.radius,
				border_size = widget.border_size,
				border_col = workspace == state.active_workspace ? widget.border_col : widget.active_border_col,
			},
			workspace == state.active_workspace ? widget.col : widget.active_col,
		)
	}

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

	workspace_rect := Rect {
		y      = y,
		width  = widget.size,
		height = widget.size,
	}

	baseline_y := centered_text_baseline(layer, workspace_rect, widget.text_size)

	for workspace, i in state.workspaces {
		x := start_x + f32(i) * (widget.size + widget.gap)
		buf: [16]u8

		text := fmt.bprintf(buf[:], "%d", workspace)
		metrics := measure_text(layer, text, widget.text_size)
		text_x := x + (widget.size - metrics.width) * 0.5

		text_col := widget.text_col
		if workspace == state.active_workspace do text_col = widget.active_text_col

		draw_text(layer, text, Vec2{text_x, baseline_y}, text_col, widget.text_size)
	}
}
