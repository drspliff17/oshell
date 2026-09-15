package main

import "base:runtime"
import "core:fmt"
import wl "wayland"

Layer :: struct {
	display:       ^wl.display,
	registry:      ^wl.registry,
	compositor:    ^wl.compositor,
	layer_shell:   ^wl.layer_shell_v1,
	surface:       ^wl.surface,
	layer_surface: ^wl.layer_surface_v1,
	configured:    bool,
	serial:        u32,
	width:         u32,
	height:        u32,
}

registry_global :: proc "cdecl" (
	data: rawptr,
	registry: ^wl.registry,
	name: uint,
	interface: cstring,
	version: uint,
) {
	layer := cast(^Layer)data

	if string(interface) == "wl_compositor" {
		layer.compositor = cast(^wl.compositor)wl.registry_bind(
			registry,
			name,
			&wl.compositor_interface,
			4,
		)
	}

	if string(interface) == "zwlr_layer_shell_v1" {
		layer.layer_shell = cast(^wl.layer_shell_v1)wl.registry_bind(
			registry,
			name,
			&wl.layer_shell_v1_interface,
			1,
		)
	}
}

registry_global_remove :: proc "cdecl" (data: rawptr, registry: ^wl.registry, name: uint) {
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

	layer.configured = true
	layer.serial = serial
	layer.width = width
	layer.height = height

	fmt.println("configure:", width, height, "serial:", serial)
}

layer_surface_closed :: proc "cdecl" (data: rawptr, surface: ^wl.layer_surface_v1) {
	context = runtime.default_context()

	layer := cast(^Layer)data
	layer.configured = false

	fmt.println("layer surface closed")
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
		.top,
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

	wl.layer_surface_v1_set_size(layer.layer_surface, 500, 100)

	wl.layer_surface_v1_set_anchor(layer.layer_surface, .top | .left)

	wl.layer_surface_v1_set_keyboard_interactivity(layer.layer_surface, .none)

	wl.surface_commit(layer.surface)

	fmt.println("layer surface created")

	for {
		if wl.display_dispatch(layer.display) < 0 {
			break
		}

		if layer.configured {
			wl.layer_surface_v1_ack_configure(layer.layer_surface, layer.serial)

			fmt.println("configured:", layer.width, layer.height)

			break
		}
	}
}
