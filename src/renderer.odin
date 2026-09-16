package main

import "core:fmt"
import wl "wayland"

request_redraw :: proc(layer: ^Layer) {
	layer.dirty = true

	if layer.frame_pending do return

	layer.dirty = false

	render(layer)
}


render :: proc(layer: ^Layer) {
	glViewport(0, 0, i32(layer.width), i32(layer.height))

	glClearColor(0.0, 0.0, 0.0, 0.0)

	glClear(GL_COLOR_BUFFER_BIT)

	// Rectangle renderer
	glUseProgram(layer.program)

	glUniform2f(layer.resolution_location, f32(layer.width), f32(layer.height))

	glBindBuffer(GL_ARRAY_BUFFER, layer.vbo)

	glEnableVertexAttribArray(0)

	glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 2 * size_of(f32), nil)

	// Bar background
	bar_rect := Rect {
		x = 0,
		y = 0,
		width = f32(layer.width),
		height = f32(layer.height),
		padding = Padding{top = 4, bottom = 4},
	}

	draw_rect(layer, bar_rect, Col{0.9, 0.1, 0.8, 0.5})

	bar_content := rect_content(bar_rect)

	// Text renderer
	glUseProgram(layer.text_program)

	glUniform2f(layer.text_resolution_location, f32(layer.width), f32(layer.height))

	glBindBuffer(GL_ARRAY_BUFFER, layer.text_vbo)

	glEnableVertexAttribArray(u32(layer.text_position_location))

	glEnableVertexAttribArray(u32(layer.text_uv_location))

	// x, y
	glVertexAttribPointer(
		u32(layer.text_position_location),
		2,
		GL_FLOAT,
		GL_FALSE,
		4 * size_of(f32),
		nil,
	)

	// u, v
	glVertexAttribPointer(
		u32(layer.text_uv_location),
		2,
		GL_FLOAT,
		GL_FALSE,
		4 * size_of(f32),
		cast(rawptr)(uintptr(2 * size_of(f32))),
	)

	// Clock
	draw_clock(
		layer,
		Clock_Widget {
			rect = {
				x = 5,
				y = bar_content.y,
				width = 70,
				height = bar_content.height,
				radius = 30,
				border_col = {1, 1, 1, 1},
				border_size = 1,
			},
			bg_col = {0, 0, 0, 1},
			text_col = {1, 1, 1, 1},
			size = 16,
		},
	)

	// Frame callback
	callback := wl.surface_frame(layer.surface)

	if callback == nil {
		fmt.eprintln("Failed to create frame callback")
	} else {
		layer.frame_pending = true

		wl.callback_add_listener(callback, &frame_listener, layer)
	}

	// Present
	if eglSwapBuffers(layer.egl_display, layer.egl_surface) == EGL_FALSE {
		fmt.eprintln("eglSwapBuffers failed")

		fmt.eprintln("EGL error:", eglGetError())

		return
	}

	if DEBUG do fmt.println("frame presented")
}
