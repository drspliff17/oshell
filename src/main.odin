package main

import "core:fmt"
import wl "wayland"

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

	fmt.println("connected")

	if layer.compositor == nil {
		fmt.eprintln("No wl_compositor")
		return
	}

	if layer.layer_shell == nil {
		fmt.eprintln("No wlr-layer-shell")
		return
	}

	fmt.println("found wl_compositor")
	fmt.println("found wlr-layer-shell")

	layer.surface = wl.compositor_create_surface(layer.compositor)

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

	fmt.println("layer surface created")

	for {
		if wl.display_dispatch(layer.display) < 0 {
			return
		}

		if layer.configured {
			break
		}
	}

	wl.layer_surface_v1_ack_configure(layer.layer_surface, layer.serial)

	fmt.println("configured:", layer.width, layer.height)

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

	fmt.println("EGL:", major, ".", minor)

	if eglBindAPI(EGL_OPENGL_ES_API) == EGL_FALSE {
		fmt.eprintln("Failed to bind OpenGL ES API")
		fmt.eprintln("EGL error:", eglGetError())
		return
	}

	config_attributes := [5]i32 {
		EGL_SURFACE_TYPE,
		EGL_WINDOW_BIT,
		EGL_RENDERABLE_TYPE,
		EGL_OPENGL_ES2_BIT,
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

	fmt.println("EGL config selected")

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

	fmt.println("OpenGL ES context created")

	glClearColor(0.08, 0.02, 0.15, 1.0)
	glClear(GL_COLOR_BUFFER_BIT)

	if eglSwapBuffers(layer.egl_display, layer.egl_surface) == EGL_FALSE {
		fmt.eprintln("eglSwapBuffers failed")
		fmt.eprintln("EGL error:", eglGetError())
		return
	}

	fmt.println("frame presented")

	for {
		if wl.display_dispatch(layer.display) < 0 {
			break
		}
	}

}
