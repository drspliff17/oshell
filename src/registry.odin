package main

import "base:runtime"
import wl "wayland"

// Receives Wayland registry globals and binds supported interfaces.
registry_global :: proc "cdecl" (
	data: rawptr,
	registry: ^wl.registry,
	name: uint,
	interface: cstring,
	version: uint,
) {
	context = runtime.default_context()

	app := cast(^App)data
	context.user_ptr = app

	interface_name := string(interface)

	if interface_name == "wl_compositor" {
		app.compositor = cast(^wl.compositor)wl.registry_bind(
			registry,
			name,
			&wl.compositor_interface,
			min(version, 4),
		)

		return
	}

	if interface_name == "zwlr_layer_shell_v1" {
		app.layer_shell = cast(^wl.layer_shell_v1)wl.registry_bind(
			registry,
			name,
			&wl.layer_shell_v1_interface,
			min(version, 1),
		)

		return
	}

	if interface_name == "wl_output" {
		output := cast(^wl.output)wl.registry_bind(
			registry,
			name,
			&wl.output_interface,
			min(version, 4),
		)

		wl.output_add_listener(output, &output_listener, app)

		return
	}
}

registry_global_remove :: proc "cdecl" (data: rawptr, registry: ^wl.registry, name: uint) {
	context = runtime.default_context()

	app := cast(^App)data
	context.user_ptr = app
}
