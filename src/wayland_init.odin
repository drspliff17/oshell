package main

import "core:fmt"
import wl "wayland"

app_registry_listener := wl.registry_listener {
	global        = registry_global,
	global_remove = registry_global_remove,
}

app_init_wayland :: proc(app: ^App) -> bool {
	app.display = wl.display_connect(nil)

	if app.display == nil {
		fmt.eprintln("Failed to connect to Wayland")
		return false
	}

	app.registry = wl.display_get_registry(app.display)
	if app.registry == nil {
		fmt.eprintln("Failed to get Wayland registry")
		app_destroy_wayland(app)
		return false
	}

	wl.registry_add_listener(app.registry, &app_registry_listener, app)

	// Discover globals.
	if wl.display_roundtrip(app.display) < 0 {
		fmt.eprintln("Failed Wayland registry roundtrip")
		app_destroy_wayland(app)
		return false
	}

	// Receive wl_output.name events.
	if wl.display_roundtrip(app.display) < 0 {
		fmt.eprintln("Failed Wayland output roundtrip")
		app_destroy_wayland(app)
		return false
	}

	if app.compositor == nil {
		fmt.eprintln("No wl_compositor")
		app_destroy_wayland(app)
		return false
	}

	if app.layer_shell == nil {
		fmt.eprintln("No wlr-layer-shell")
		app_destroy_wayland(app)
		return false
	}

	if app_preferred_output(app) == nil {
		fmt.eprintln("Neither HDMI-A-1 nor eDP-1 found")
		app_destroy_wayland(app)
		return false
	}

	if DEBUG {
		fmt.println("connected")
		fmt.println("found wl_compositor")
		fmt.println("found wlr-layer-shell")
	}

	return true
}

app_destroy_wayland :: proc(app: ^App) {
	if app.display == nil do return

	wl.display_disconnect(app.display)
	app.display = nil
	app.registry = nil
	app.compositor = nil
	app.layer_shell = nil

	app.hdmi_output = nil
	app.edp_output = nil
}
