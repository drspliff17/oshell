package main

import "core:fmt"
import wl "wayland"

render :: proc(layer: ^Layer) {
	glViewport(0, 0, i32(layer.width), i32(layer.height))

	glClearColor(0.0, 0.0, 0.0, 0.0)

	glClear(GL_COLOR_BUFFER_BIT)

	glUseProgram(layer.program)

	glUniform2f(layer.resolution_location, f32(layer.width), f32(layer.height))

	glBindBuffer(GL_ARRAY_BUFFER, layer.vbo)

	glEnableVertexAttribArray(0)

	glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 2 * size_of(f32), nil)

	draw_rect(layer, Rect{x = 0, y = 0, width = 1920, height = 1080}, Col{0.9, 0.1, 0.8, 0.5})

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

	draw_text(layer, "hello world", Vec2{20, 22}, Col{1, 1, 1, 1})

	callback := wl.surface_frame(layer.surface)

	if callback == nil {
		fmt.eprintln("Failed to create frame callback")
	} else {
		layer.frame_pending = true

		wl.callback_add_listener(callback, &frame_listener, layer)
	}

	if eglSwapBuffers(layer.egl_display, layer.egl_surface) == EGL_FALSE {
		fmt.eprintln("eglSwapBuffers failed")
		fmt.eprintln("EGL error:", eglGetError())
		return
	}

	if DEBUG do fmt.println("frame presented")
}
