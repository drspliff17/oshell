package main

import "base:runtime"
import "core:fmt"
import "core:strings"
import wl "wayland"

DEBUG :: true

frame_listener := wl.callback_listener {
	done = frame_done,
}

frame_done :: proc "c" (data: rawptr, callback: ^wl.callback, time: uint) {
	context = runtime.default_context()

	layer := cast(^Layer)data

	wl.callback_destroy(callback)

	request_frame(layer)
	render(layer)
}

request_frame :: proc(layer: ^Layer) {
	callback := wl.surface_frame(layer.surface)

	if callback == nil {
		fmt.eprintln("Failed to create frame callback")
		return
	}

	wl.callback_add_listener(callback, &frame_listener, layer)
}

main :: proc() {
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

	layer.surface = wl.compositor_create_surface(layer.compositor)

	if layer.surface == nil {
		fmt.eprintln("Failed to create wl_surface")
		return
	}

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

	layer.egl_window = wl.egl_window_create(layer.surface, int(layer.width), int(layer.height))

	if layer.egl_window == nil {
		fmt.eprintln("Failed to create EGL window")
		return
	}

	defer wl.egl_window_destroy(layer.egl_window)

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

	if DEBUG do fmt.println("EGL:", major, ".", minor)

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

	// FreeType

	library: FT_Library

	if FT_Init_FreeType(&library) != 0 {
		fmt.eprintln("Failed to initialize FreeType")
		return
	}

	defer FT_Done_FreeType(library)

	font_path := "/usr/share/fonts/noto/NotoSans-Regular.ttf"

	font_path_cstr := strings.clone_to_cstring(font_path)
	defer delete(font_path_cstr)

	face: FT_Face

	if FT_New_Face(library, font_path_cstr, 0, &face) != 0 {
		fmt.eprintln("Failed to load font")
		return
	}

	defer FT_Done_Face(face)

	if FT_Set_Pixel_Sizes(face, 0, 16) != 0 {
		fmt.eprintln("Failed to set font size")
		return
	}

	layer.font_face = face

	if DEBUG do fmt.println("FreeType font loaded")

	//
	// Rectangle shader
	//

	vertex_shader_source := `
attribute vec2 position;

uniform vec2 resolution;

void main() {
    vec2 zero_to_one = position / resolution;
    vec2 zero_to_two = zero_to_one * 2.0;
    vec2 clip_space = zero_to_two - 1.0;

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

	layer.program = create_program(vertex_shader_source, fragment_shader_source)

	if layer.program == 0 {
		fmt.eprintln("Failed to create shader program")
		return
	}

	defer glDeleteProgram(layer.program)

	layer.resolution_location = glGetUniformLocation(layer.program, "resolution")

	layer.color_location = glGetUniformLocation(layer.program, "color")

	if layer.resolution_location < 0 {
		fmt.eprintln("Failed to find resolution uniform")
		return
	}

	if layer.color_location < 0 {
		fmt.eprintln("Failed to find color uniform")
		return
	}

	if DEBUG do fmt.println("rectangle shader program created")

	//
	// Rectangle VBO
	//

	glGenBuffers(1, &layer.vbo)

	defer glDeleteBuffers(1, &layer.vbo)

	glBindBuffer(GL_ARRAY_BUFFER, layer.vbo)

	glBufferData(GL_ARRAY_BUFFER, 12 * size_of(f32), nil, GL_DYNAMIC_DRAW)

	//
	// Text shader
	//

	text_vertex_shader_source := `
attribute vec2 position;
attribute vec2 tex_coord;

uniform vec2 resolution;

varying vec2 v_tex_coord;

void main() {
    vec2 zero_to_one = position / resolution;
    vec2 zero_to_two = zero_to_one * 2.0;
    vec2 clip_space = zero_to_two - 1.0;

    clip_space.y = -clip_space.y;

    gl_Position = vec4(clip_space, 0.0, 1.0);

    v_tex_coord = tex_coord;
}
`

	text_fragment_shader_source := `
precision mediump float;

uniform sampler2D glyph_texture;
uniform vec4 text_color;

varying vec2 v_tex_coord;

void main() {
    float coverage = texture2D(
        glyph_texture,
        v_tex_coord
    ).a;

    gl_FragColor = vec4(
        text_color.rgb,
        text_color.a * coverage
    );
}
`

	layer.text_program = create_program(text_vertex_shader_source, text_fragment_shader_source)

	if layer.text_program == 0 {
		fmt.eprintln("Failed to create text shader program")
		return
	}

	defer glDeleteProgram(layer.text_program)

	layer.text_position_location = glGetAttribLocation(layer.text_program, "position")

	layer.text_uv_location = glGetAttribLocation(layer.text_program, "tex_coord")

	layer.text_resolution_location = glGetUniformLocation(layer.text_program, "resolution")

	layer.text_color_location = glGetUniformLocation(layer.text_program, "text_color")

	layer.text_texture_location = glGetUniformLocation(layer.text_program, "glyph_texture")

	if layer.text_position_location < 0 {
		fmt.eprintln("Failed to find text position attribute")
		return
	}

	if layer.text_uv_location < 0 {
		fmt.eprintln("Failed to find text tex_coord attribute")
		return
	}

	if layer.text_resolution_location < 0 {
		fmt.eprintln("Failed to find text resolution uniform")
		return
	}

	if layer.text_color_location < 0 {
		fmt.eprintln("Failed to find text color uniform")
		return
	}

	if layer.text_texture_location < 0 {
		fmt.eprintln("Failed to find glyph texture uniform")
		return
	}

	if DEBUG do fmt.println("text shader program created")

	//
	// Text VBO
	//
	// 6 vertices
	// x, y, u, v = 4 floats each
	//

	glGenBuffers(1, &layer.text_vbo)

	defer glDeleteBuffers(1, &layer.text_vbo)

	glBindBuffer(GL_ARRAY_BUFFER, layer.text_vbo)

	glBufferData(GL_ARRAY_BUFFER, 24 * size_of(f32), nil, GL_DYNAMIC_DRAW)

	//
	// Blending
	//

	glEnable(GL_BLEND)

	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)

	if DEBUG do fmt.println("renderer initialized")

	request_frame(&layer)
	render(&layer)

	for {
		if wl.display_dispatch(layer.display) < 0 {
			break
		}
	}
}
