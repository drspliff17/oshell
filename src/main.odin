package main

import "core:fmt"
import wl "wayland"

DEBUG :: true

main :: proc() {
	// Wayland Connection
	layer := Layer{}
	layer.display = wl.display_connect(nil)
	if layer.display == nil {
		fmt.eprintln("Failed to connect")
		return
	}
	defer wl.display_disconnect(layer.display)

	layer.registry = wl.display_get_registry(layer.display)

	registry_listener := wl.registry_listener {
		global        = registry_global,
		global_remove = registry_global_remove,
	}

	wl.registry_add_listener(layer.registry, &registry_listener, &layer)

	wl.display_roundtrip(layer.display)

	if DEBUG do fmt.println("connected")

	if layer.compositor == nil {
		fmt.eprintln("No wl_compositor")
		return
	}
	if DEBUG do fmt.println("found wl_compositor")

	if layer.layer_shell == nil {
		fmt.eprintln("No wlr-layer-shell")
		return
	}
	if DEBUG do fmt.println("found wlr-layer-shell")


	// wl_surface
	layer.surface = wl.compositor_create_surface(layer.compositor)

	if layer.surface == nil {
		fmt.eprintln("Failed to create wl_surface")
		return
	}

	// layer-shell surface
	layer.layer_surface = wl.layer_shell_v1_get_layer_surface(
		layer.layer_shell,
		layer.surface,
		nil,
		.overlay,
		"oshell",
	)

	if layer.layer_surface == nil {
		fmt.eprintln("Failed to create layer surface")
		return
	}

	layer_surface_listener := wl.layer_surface_v1_listener {
		configure = layer_surface_configure,
		closed    = layer_surface_closed,
	}

	wl.layer_surface_v1_add_listener(layer.layer_surface, &layer_surface_listener, &layer)


	// Layer-shell configuration
	wl.layer_surface_v1_set_size(layer.layer_surface, 1920, 32)
	wl.layer_surface_v1_set_anchor(layer.layer_surface, .bottom | .left | .right)
	wl.layer_surface_v1_set_exclusive_zone(layer.layer_surface, 32)
	wl.layer_surface_v1_set_keyboard_interactivity(layer.layer_surface, .none)

	wl.surface_commit(layer.surface)

	if DEBUG do fmt.println("layer surface created")

	for {
		if wl.display_dispatch(layer.display) < 0 {
			return
		}

		if layer.configured {
			break
		}
	}

	wl.layer_surface_v1_ack_configure(layer.layer_surface, layer.serial)
	if DEBUG do fmt.println("configured:", layer.width, layer.height)


	// EGL window
	layer.egl_window = wl.egl_window_create(layer.surface, int(layer.width), int(layer.height))

	if layer.egl_window == nil {
		fmt.eprintln("Failed to create EGL window")
		return
	}

	defer wl.egl_window_destroy(layer.egl_window)

	// EGL display
	layer.egl_display = eglGetDisplay(cast(rawptr)layer.display)

	if layer.egl_display == nil {
		fmt.eprintln("Failed to get EGL display")
		return
	}

	major: i32
	minor: i32

	if eglInitialize(layer.egl_display, &major, &minor) == EGL_FALSE {
		fmt.eprintln("Failed to initialize EGL")
		fmt.eprintln("EGL error:", eglGetError())
		return
	}

	defer eglTerminate(layer.egl_display)

	fmt.println("EGL:", major, ".", minor)


	// EGL API
	if eglBindAPI(EGL_OPENGL_ES_API) == EGL_FALSE {
		fmt.eprintln("Failed to bind OpenGL ES API")
		fmt.eprintln("EGL error:", eglGetError())
		return
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

	if eglChooseConfig(
		   layer.egl_display,
		   &config_attributes[0],
		   &layer.egl_config,
		   1,
		   &num_configs,
	   ) ==
	   EGL_FALSE {
		fmt.eprintln("Failed to choose EGL config")
		fmt.eprintln("EGL error:", eglGetError())
		return
	}

	if num_configs == 0 {
		fmt.eprintln("No suitable EGL configs")
		fmt.eprintln("EGL error:", eglGetError())
		return
	}

	if DEBUG do fmt.println("EGL config selected")


	// EGL context
	context_attributes := [3]i32{EGL_CONTEXT_CLIENT_VERSION, 2, EGL_NONE}

	layer.egl_context = eglCreateContext(
		layer.egl_display,
		layer.egl_config,
		nil,
		&context_attributes[0],
	)

	if layer.egl_context == nil {
		fmt.eprintln("Failed to create EGL context")
		fmt.eprintln("EGL error:", eglGetError())
		return
	}

	defer eglDestroyContext(layer.egl_display, layer.egl_context)

	// EGL surface
	layer.egl_surface = eglCreateWindowSurface(
		layer.egl_display,
		layer.egl_config,
		cast(rawptr)layer.egl_window,
		nil,
	)

	if layer.egl_surface == nil {
		fmt.eprintln("Failed to create EGL surface")
		fmt.eprintln("EGL error:", eglGetError())
		return
	}

	defer eglDestroySurface(layer.egl_display, layer.egl_surface)


	// EGL context
	if eglMakeCurrent(
		   layer.egl_display,
		   layer.egl_surface,
		   layer.egl_surface,
		   layer.egl_context,
	   ) ==
	   EGL_FALSE {
		fmt.eprintln("Failed to make EGL context current")
		fmt.eprintln("EGL error:", eglGetError())
		return
	}

	if DEBUG do fmt.println("OpenGL ES context created")

	vertex_shader_source := `
attribute vec2 position;

uniform vec2 resolution;

void main() {
    vec2 zero_to_one = position / resolution;

    vec2 zero_to_two = zero_to_one * 2.0;

    vec2 clip_space = zero_to_two - 1.0;

    // OpenGL's Y axis points upwards, whereas our UI
    // coordinates start at the top.
    clip_space.y = -clip_space.y;

    gl_Position = vec4(clip_space, 0.0, 1.0);
}
`

	fragment_shader_source := `
precision mediump float;

uniform vec4 color;

void main() {
    gl_FragColor = color;
}
`


	// Shader program
	program := create_program(vertex_shader_source, fragment_shader_source)

	if program == 0 {
		fmt.eprintln("Failed to create shader program")
		return
	}

	defer glDeleteProgram(program)

	fmt.println("shader program created")


	// Uniforms
	resolution_location := glGetUniformLocation(program, "resolution")

	color_location := glGetUniformLocation(program, "color")

	if resolution_location < 0 {
		fmt.eprintln("Failed to find resolution uniform")
		return
	}

	if color_location < 0 {
		fmt.eprintln("Failed to find color uniform")
		return
	}


	//TEST:
	// Rectangle vertex buffer
	x: f32 = 0
	y: f32 = 0

	rect_width: f32 = 1920
	rect_height: f32 = 32

	vertices := [12]f32 {
		// Triangle 1
		x,
		y,
		x + rect_width,
		y,
		x + rect_width,
		y + rect_height,

		// Triangle 2
		x,
		y,
		x + rect_width,
		y + rect_height,
		x,
		y + rect_height,
	}


	// VBO
	vbo: u32

	glGenBuffers(1, &vbo)

	defer glDeleteBuffers(1, &vbo)

	glBindBuffer(GL_ARRAY_BUFFER, vbo)

	glBufferData(GL_ARRAY_BUFFER, size_of(vertices), &vertices[0], GL_STATIC_DRAW)

	glEnable(GL_BLEND)

	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)


	// Render
	glViewport(0, 0, i32(layer.width), i32(layer.height))

	glClearColor(0.0, 0.0, 0.0, 0.0)

	glClear(GL_COLOR_BUFFER_BIT)

	glUseProgram(program)

	glUniform2f(resolution_location, f32(layer.width), f32(layer.height))

	glUniform4f(color_location, 0.8, 0.1, 0.9, 1.0)


	// Vertex attribute
	glBindBuffer(GL_ARRAY_BUFFER, vbo)

	glEnableVertexAttribArray(0)

	glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 2 * size_of(f32), nil)

	// Draw
	glDrawArrays(GL_TRIANGLES, 0, 6)

	if eglSwapBuffers(layer.egl_display, layer.egl_surface) == EGL_FALSE {
		fmt.eprintln("eglSwapBuffers failed")
		fmt.eprintln("EGL error:", eglGetError())
		return
	}

	if DEBUG do fmt.println("frame presented")

	for {
		if wl.display_dispatch(layer.display) < 0 {
			break
		}
	}
}
