package main

import "base:runtime"
import "core:fmt"
import wl "wayland"

OUTPUT_MODES :: enum {
	Preferred,
	Inverted,
	All,
	Hide,
}

output_listener := wl.output_listener {
	geometry    = output_geometry,
	mode        = output_mode,
	done        = output_done,
	scale       = output_scale,
	name        = output_name,
	description = output_description,
}

output_geometry :: proc "c" (
	data: rawptr,
	output: ^wl.output,
	x: int,
	y: int,
	physical_width: int,
	physical_height: int,
	subpixel: wl.output_subpixel,
	make: cstring,
	model: cstring,
	transform: wl.output_transform,
) {
}

output_mode :: proc "c" (
	data: rawptr,
	output: ^wl.output,
	flags: wl.output_mode,
	width: int,
	height: int,
	refresh: int,
) {
}

output_done :: proc "c" (data: rawptr, output: ^wl.output) {}

output_scale :: proc "c" (data: rawptr, output: ^wl.output, factor: int) {}

output_name :: proc "cdecl" (data: rawptr, output: ^wl.output, name: cstring) {
	context = runtime.default_context()

	app := cast(^App)data
	context.user_ptr = app

	output_name := string(name)
	switch output_name {
	case "HDMI-A-1":
		app.hdmi_output = output
	case "eDP-1":
		app.edp_output = output
	}
	if DEBUG do fmt.println("output:", output_name)
}

output_description :: proc "c" (data: rawptr, output: ^wl.output, description: cstring) {}
