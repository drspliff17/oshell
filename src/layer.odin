package main

import "base:runtime"
import "core:fmt"
import wl "wayland"

Layer_Type :: enum {
	Bar,
	Notification,
}

BAR_LAYER_HEIGHT :: 28
BAR_EXCLUSIVE_ZONE :: 32

NOTIFICATION_MAX_WIDTH :: 360
NOTIFICATION_PADDING_X :: 14
NOTIFICATION_PADDING_Y :: 8
NOTIFICATION_TEXT_GAP :: 4

Layer :: struct {
	using app:           ^App,

	// Output this layer belongs to
	output:              ^wl.output,

	// Wayland surface
	surface:             ^wl.surface,
	layer_surface:       ^wl.layer_surface_v1,

	// EGL surface
	egl_window:          ^wl.egl_window,
	egl_surface:         EGLSurface,

	// Layer type
	layer_type:          Layer_Type,

	// Notification only
	notification_id:     u32,
	notification_width:  u32,
	notification_height: u32,
	margin_left:         int,
	margin_top:          int,

	// Configure state
	serial:              u32,
	width:               u32,
	height:              u32,
	configured:          bool,

	// Frame lifecycle
	frame_pending:       bool,
	redraw_pending:      bool,
	frame_callback:      ^wl.callback,
}

layer_surface_listener := wl.layer_surface_v1_listener {
	configure = layer_surface_configure,
	closed    = layer_surface_closed,
}

layer_surface_configure :: proc "cdecl" (
	data: rawptr,
	surface: ^wl.layer_surface_v1,
	serial: u32,
	width: u32,
	height: u32,
) {
	context = runtime.default_context()

	layer := cast(^Layer)data
	context.user_ptr = layer.app

	layer.serial = serial
	layer.width = width
	layer.height = height
	layer.configured = true

	wl.layer_surface_v1_ack_configure(surface, serial)

	if layer.egl_window != nil do wl.egl_window_resize(layer.egl_window, int(width), int(height), 0, 0)
	if DEBUG do fmt.println("configure:", layer.layer_type, width, height, "serial:", serial)
}

layer_surface_closed :: proc "cdecl" (data: rawptr, surface: ^wl.layer_surface_v1) {
	context = runtime.default_context()

	layer := cast(^Layer)data
	context.user_ptr = layer.app
	layer.configured = false

	if DEBUG do fmt.println("layer surface closed:", layer.layer_type)
}

layer_make_current :: proc(layer: ^Layer) -> bool {
	if layer.app.current_layer == layer do return true

	if eglMakeCurrent(
		   layer.egl_display,
		   layer.egl_surface,
		   layer.egl_surface,
		   layer.egl_context,
	   ) ==
	   EGL_FALSE {
		fmt.eprintln("Failed to make EGL context current")
		fmt.eprintln("EGL error:", eglGetError())
		return false
	}

	layer.app.current_layer = layer
	return true
}

layer_create_surface :: proc(layer: ^Layer, output: ^wl.output) -> bool {
	if output == nil do return false

	layer.output = output
	layer.configured = false
	layer.frame_pending = false
	layer.redraw_pending = false
	layer.frame_callback = nil

	layer.surface = wl.compositor_create_surface(layer.compositor)

	if layer.surface == nil {
		fmt.eprintln("Failed to create wl_surface")
		return false
	}

	namespace: cstring = layer.layer_type == .Bar ? "oshell-bar" : "oshell-notification"

	layer.layer_surface = wl.layer_shell_v1_get_layer_surface(
		layer.layer_shell,
		layer.surface,
		output,
		.overlay,
		namespace,
	)

	if layer.layer_surface == nil {
		fmt.eprintln("Failed to create layer surface")
		wl.surface_destroy(layer.surface)
		layer.surface = nil
		return false
	}

	wl.layer_surface_v1_add_listener(layer.layer_surface, &layer_surface_listener, layer)

	switch layer.layer_type {
	case .Bar:
		wl.layer_surface_v1_set_size(layer.layer_surface, 0, BAR_LAYER_HEIGHT)
		wl.layer_surface_v1_set_anchor(layer.layer_surface, .bottom | .left | .right)
		wl.layer_surface_v1_set_exclusive_zone(layer.layer_surface, BAR_EXCLUSIVE_ZONE)

	case .Notification:
		if layer.notification_width == 0 do layer.notification_width = 1
		if layer.notification_height == 0 do layer.notification_height = 1

		wl.layer_surface_v1_set_size(
			layer.layer_surface,
			layer.notification_width,
			layer.notification_height,
		)

		wl.layer_surface_v1_set_anchor(layer.layer_surface, .top | .left)
		wl.layer_surface_v1_set_exclusive_zone(layer.layer_surface, 0)

		wl.layer_surface_v1_set_margin(
			layer.layer_surface,
			i32(layer.margin_top),
			0,
			0,
			i32(layer.margin_left),
		)
	}

	wl.layer_surface_v1_set_keyboard_interactivity(layer.layer_surface, .none)
	wl.surface_commit(layer.surface)

	if wl.display_flush(layer.display) < 0 {
		fmt.eprintln("Failed to flush layer surface commit")
		return false
	}
	if DEBUG do fmt.println("waiting for layer configure:", layer.layer_type)

	for !layer.configured {
		if wl.display_dispatch(layer.display) < 0 {
			fmt.eprintln("Failed while waiting for layer configure")
			return false
		}
	}
	if DEBUG do fmt.println("layer configured:", layer.layer_type, layer.width, "x", layer.height)

	layer.egl_window = wl.egl_window_create(layer.surface, int(layer.width), int(layer.height))
	if layer.egl_window == nil {
		fmt.eprintln("Failed to create EGL window")
		return false
	}

	layer.egl_surface = eglCreateWindowSurface(
		layer.egl_display,
		layer.egl_config,
		cast(rawptr)layer.egl_window,
		nil,
	)

	if layer.egl_surface == nil {
		fmt.eprintln("Failed to create EGL surface")
		fmt.eprintln("EGL error:", eglGetError())
		wl.egl_window_destroy(layer.egl_window)
		layer.egl_window = nil
		return false
	}
	if !layer_make_current(layer) do return false

	if DEBUG do fmt.println("layer created:", layer.layer_type, layer.width, "x", layer.height)
	return true
}

layer_set_position :: proc(layer: ^Layer, x: int, y: int) {
	if layer.layer_type != .Notification do return

	layer.margin_left = x
	layer.margin_top = y

	if layer.layer_surface == nil do return

	wl.layer_surface_v1_set_margin(layer.layer_surface, i32(y), 0, 0, i32(x))
	wl.surface_commit(layer.surface)
}

layer_destroy_surface :: proc(layer: ^Layer) {
	if layer.frame_callback != nil {
		wl.callback_destroy(layer.frame_callback)
		layer.frame_callback = nil
	}

	layer.frame_pending = false
	layer.redraw_pending = false

	if layer.app.current_layer == layer {
		eglMakeCurrent(layer.egl_display, nil, nil, nil)
		layer.app.current_layer = nil
	}

	if layer.egl_surface != nil {
		eglDestroySurface(layer.egl_display, layer.egl_surface)
		layer.egl_surface = nil
	}

	if layer.egl_window != nil {
		wl.egl_window_destroy(layer.egl_window)
		layer.egl_window = nil
	}

	if layer.layer_surface != nil {
		wl.layer_surface_v1_destroy(layer.layer_surface)
		layer.layer_surface = nil
	}

	if layer.surface != nil {
		wl.surface_destroy(layer.surface)
		layer.surface = nil
	}

	layer.output = nil
	layer.configured = false

	layer.serial = 0
	layer.width = 0
	layer.height = 0
}

layer_set_output :: proc(layer: ^Layer, output: ^wl.output) -> bool {
	if output == nil do return false
	if layer.output == output do return true

	old_output := layer.output

	layer_destroy_surface(layer)
	if layer_create_surface(layer, output) {
		request_redraw(layer)
		return true
	}

	if old_output != nil {
		if layer_create_surface(layer, old_output) do request_redraw(layer)
	}

	return false
}
