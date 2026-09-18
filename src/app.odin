package main

import "core:fmt"
import wl "wayland"

App :: struct {
	// Layers
	layers:                        [dynamic]^Layer,
	current_layer:                 ^Layer,

	// Wayland globals
	display:                       ^wl.display,
	registry:                      ^wl.registry,
	compositor:                    ^wl.compositor,
	layer_shell:                   ^wl.layer_shell_v1,

	// Outputs
	hdmi_output:                   ^wl.output,
	edp_output:                    ^wl.output,

	// IPC
	hypr:                          Hyprland_IPC,
	ipc:                           Oshell_IPC,

	// EGL shared state
	egl_display:                   EGLDisplay,
	egl_config:                    EGLConfig,
	egl_context:                   EGLContext,

	// Font rendering state
	font_face:                     FT_Face,
	font:                          Font,

	// Rectangle renderer
	program:                       u32,
	vbo:                           u32,
	resolution_location:           i32,
	color_location:                i32,
	rect_position_location:        i32,
	rect_size_location:            i32,
	rect_radius_location:          i32,
	rect_vertex_position_location: i32,

	// Text renderer
	text_program:                  u32,
	text_vbo:                      u32,
	text_position_location:        i32,
	text_uv_location:              i32,
	text_resolution_location:      i32,
	text_color_location:           i32,
	text_texture_location:         i32,

	// Output configuration
	output_mode:                   OUTPUT_MODES,

	//
	exit_requested:                bool,
}

get_app :: proc() -> ^App {return cast(^App)context.user_ptr}

app_preferred_output :: proc(app: ^App) -> ^wl.output {
	if app.hdmi_output != nil do return app.hdmi_output
	return app.edp_output
}

app_inverted_output :: proc(app: ^App) -> ^wl.output {
	preferred := app_preferred_output(app)
	if preferred == app.hdmi_output && app.edp_output != nil do return app.edp_output
	if preferred == app.edp_output && app.hdmi_output != nil do return app.hdmi_output
	return preferred
}

app_find_layer :: proc(app: ^App, output: ^wl.output) -> ^Layer {
	for layer in app.layers do if layer.output == output do return layer
	return nil
}

app_create_layer :: proc(app: ^App, output: ^wl.output) -> ^Layer {
	if output == nil do return nil

	layer := new(Layer)
	layer.app = app

	if !layer_create_surface(layer, output) {
		free(layer)
		return nil
	}

	append(&app.layers, layer)
	return layer
}

app_destroy_layer :: proc(app: ^App, index: int) {
	if index < 0 || index >= len(app.layers) do return

	layer := app.layers[index]
	layer_destroy_surface(layer)
	free(layer)
	ordered_remove(&app.layers, index)
}

app_destroy_extra_layers :: proc(app: ^App) {
	for len(app.layers) > 1 do app_destroy_layer(app, len(app.layers) - 1)
}

app_destroy_layers :: proc(app: ^App) {
	for len(app.layers) > 0 do app_destroy_layer(app, len(app.layers) - 1)
}

request_redraw_all :: proc(app: ^App) {
	for layer in app.layers {
		if !layer.configured do continue
		if layer.egl_surface == nil do continue
		request_redraw(layer)
	}
}

app_set_output_mode :: proc(app: ^App, mode: OUTPUT_MODES) -> bool {
	if len(app.layers) == 0 do return false

	primary := app.layers[0]
	switch mode {
	case .Preferred:
		output := app_preferred_output(app)
		if output == nil do return false

		app_destroy_extra_layers(app)
		if !layer_set_output(primary, output) do return false

		app.output_mode = .Preferred
		request_redraw(primary)

		return true

	case .Inverted:
		output := app_inverted_output(app)
		if output == nil do return false

		app_destroy_extra_layers(app)

		if !layer_set_output(primary, output) do return false
		app.output_mode = .Inverted

		request_redraw(primary)
		return true

	case .All:
		primary_output := app_preferred_output(app)
		if primary_output == nil do return false

		if !layer_set_output(primary, primary_output) do return false
		second_output: ^wl.output

		if primary_output == app.hdmi_output {
			second_output = app.edp_output
		} else {
			second_output = app.hdmi_output
		}

		if second_output != nil && app_find_layer(app, second_output) == nil {
			secondary := app_create_layer(app, second_output)
			if secondary == nil do return false
		}

		app.output_mode = .All
		request_redraw_all(app)

		return true
	}

	return false
}

app_toggle_output :: proc(app: ^App) -> bool {
	switch app.output_mode {
	case .Preferred:
		return app_set_output_mode(app, .Inverted)

	case .Inverted:
		return app_set_output_mode(app, .Preferred)

	case .All:
		return app_set_output_mode(app, .Preferred)
	}

	return false
}

app_init_egl :: proc(app: ^App) -> bool {
	app.egl_display = eglGetDisplay(cast(rawptr)app.display)

	if app.egl_display == nil {
		fmt.eprintln("Failed to get EGL display")
		return false
	}

	major: i32
	minor: i32

	if eglInitialize(app.egl_display, &major, &minor) == EGL_FALSE {
		fmt.eprintln("Failed to initialize EGL")
		fmt.eprintln("EGL error:", eglGetError())
		return false
	}

	if DEBUG do fmt.println("EGL:", major, ".", minor)

	if eglBindAPI(EGL_OPENGL_ES_API) == EGL_FALSE {
		fmt.eprintln("Failed to bind OpenGL ES API")
		fmt.eprintln("EGL error:", eglGetError())
		return false
	}

	config_attributes := [7]i32 {
		EGL_SURFACE_TYPE,
		EGL_WINDOW_BIT,
		EGL_RENDERABLE_TYPE,
		EGL_OPENGL_ES2_BIT,
		EGL_ALPHA_SIZE,
		8,
		EGL_NONE,
	}

	num_configs: i32

	if eglChooseConfig(app.egl_display, &config_attributes[0], &app.egl_config, 1, &num_configs) ==
	   EGL_FALSE {
		fmt.eprintln("Failed to choose EGL config")
		fmt.eprintln("EGL error:", eglGetError())
		return false
	}

	if num_configs == 0 {
		fmt.eprintln("No suitable EGL configs")
		return false
	}

	if DEBUG do fmt.println("EGL config selected")

	context_attributes := [3]i32{EGL_CONTEXT_CLIENT_VERSION, 2, EGL_NONE}

	app.egl_context = eglCreateContext(
		app.egl_display,
		app.egl_config,
		nil,
		&context_attributes[0],
	)

	if app.egl_context == nil {
		fmt.eprintln("Failed to create EGL context")
		fmt.eprintln("EGL error:", eglGetError())
		return false
	}

	return true
}

app_destroy_egl :: proc(app: ^App) {
	if app.egl_display == nil do return
	eglMakeCurrent(app.egl_display, nil, nil, nil)
	app.current_layer = nil

	if app.egl_context != nil {
		eglDestroyContext(app.egl_display, app.egl_context)
		app.egl_context = nil
	}

	eglTerminate(app.egl_display)
	app.egl_display = nil
}
