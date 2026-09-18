package main

import "base:runtime"
import "core:fmt"
import wl "wayland"

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

output_done :: proc "c" (data: rawptr, output: ^wl.output) {
}

output_scale :: proc "c" (data: rawptr, output: ^wl.output, factor: int) {
}

output_name :: proc "c" (data: rawptr, output: ^wl.output, name: cstring) {
	context = runtime.default_context()

	layer := cast(^Layer)data
	name_string := string(name)

	if DEBUG do fmt.println("output:", name_string)

	switch name_string {
	case "HDMI-A-1":
		layer.hdmi_output = output

	case "eDP-1":
		layer.edp_output = output
	}
}

output_description :: proc "c" (data: rawptr, output: ^wl.output, description: cstring) {
}
