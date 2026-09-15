package main

import "core:fmt"
import wl "wayland"

Layer :: struct {
	display:       ^wl.display,
	registry:      ^wl.registry,
	compositor:    ^wl.compositor,
	layer_shell:   ^wl.layer_shell_v1,
	surface:       ^wl.surface,
	layer_surface: ^wl.layer_surface_v1,
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

main :: proc() {
	layer := Layer{}

	layer.display = wl.display_connect(nil)
	if layer.display == nil {
		fmt.eprintln("Failed to connect")
		return
	}
	defer wl.display_disconnect(layer.display)

	layer.registry = wl.display_get_registry(layer.display)

	listener := wl.registry_listener {
		global        = registry_global,
		global_remove = registry_global_remove,
	}

	wl.registry_add_listener(layer.registry, &listener, &layer)
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

	wl.layer_surface_v1_set_size(layer.layer_surface, 500, 100)

	wl.layer_surface_v1_set_anchor(layer.layer_surface, .top | .left)

	wl.layer_surface_v1_set_keyboard_interactivity(layer.layer_surface, .none)

	wl.surface_commit(layer.surface)

	fmt.println("layer surface created")

	for {
		if wl.display_dispatch(layer.display) < 0 {
			break
		}
	}
}
