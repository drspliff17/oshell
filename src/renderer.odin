package main

import "core:fmt"
import wl "wayland"

Render_State :: struct {
	// Rectangle renderer
	program:                       u32,
	vbo:                           u32,
	resolution_location:           i32,
	color_location:                i32,
	border_color_location:         i32,
	rect_position_location:        i32,
	rect_size_location:            i32,
	rect_radius_location:          i32,
	border_size_location:          i32,
	rect_vertex_position_location: i32,

	// Text renderer
	text_program:                  u32,
	text_vbo:                      u32,
	text_position_location:        i32,
	text_uv_location:              i32,
	text_resolution_location:      i32,
	text_color_location:           i32,
	text_texture_location:         i32,
}

request_redraw :: proc(layer: ^Layer) {
	if layer == nil do return
	if layer.app.output_mode == .Hide do return
	if !layer.configured do return
	if layer.egl_surface == nil do return
	if layer.frame_pending {
		layer.redraw_pending = true
		return
	}
	render(layer)
}

request_redraw_all :: proc(app: ^App) {
	for layer in app.layers {
		if !layer.configured do continue
		if layer.egl_surface == nil do continue
		request_redraw(layer)
	}
}

render :: proc(layer: ^Layer) {
	if layer == nil do return
	if layer.app.output_mode == .Hide do return
	if !layer.configured do return
	if layer.egl_surface == nil do return
	if !layer_make_current(layer) do return
	layer.redraw_pending = false

	glViewport(0, 0, i32(layer.width), i32(layer.height))

	glDisable(GL_SCISSOR_TEST)
	glDisable(GL_BLEND)

	glClearColor(0.0, 0.0, 0.0, 0.0)
	glClear(GL_COLOR_BUFFER_BIT)

	glEnable(GL_BLEND)

	switch layer.layer_type {
	case .Bar:
		render_bar_layer(layer)

	case .Notification:
		render_notification_layer(layer)
	}

	if !layer.frame_pending {
		callback := wl.surface_frame(layer.surface)

		if callback == nil {
			fmt.eprintln("Failed to create frame callback")
		} else {
			layer.frame_callback = callback
			layer.frame_pending = true

			wl.callback_add_listener(callback, &frame_listener, layer)
		}
	}

	wl.surface_damage(layer.surface, 0, 0, int(layer.width), int(layer.height))

	wl.surface_damage_buffer(layer.surface, 0, 0, int(layer.width), int(layer.height))

	if eglSwapBuffers(layer.egl_display, layer.egl_surface) == EGL_FALSE {
		fmt.eprintln("eglSwapBuffers failed")
		fmt.eprintln("EGL error:", eglGetError())
		return
	}

	if DEBUG do fmt.println("frame presented:", layer.layer_type)
}
