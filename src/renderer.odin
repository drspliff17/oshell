package main

import "core:fmt"

render :: proc(layer: ^Layer) {
	glViewport(0, 0, i32(layer.width), i32(layer.height))

	glClearColor(0.0, 0.0, 0.0, 0.0)
	glClear(GL_COLOR_BUFFER_BIT)

	glUseProgram(layer.program)

	glUniform2f(layer.resolution_location, f32(layer.width), f32(layer.height))

	glBindBuffer(GL_ARRAY_BUFFER, layer.vbo)

	glEnableVertexAttribArray(0)

	glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 2 * size_of(f32), nil)

	draw_rect(layer, 0, 0, 1920, 32, 0.8, 0.1, 0.9, 1.0)

	if eglSwapBuffers(layer.egl_display, layer.egl_surface) == EGL_FALSE {
		fmt.eprintln("eglSwapBuffers failed")
		fmt.eprintln("EGL error:", eglGetError())
		return
	}

	if DEBUG do fmt.println("frame presented")
}
