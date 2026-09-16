package main

import "base:runtime"
import "core:fmt"
import wl "wayland"

Layer :: struct {
	display:                  ^wl.display,
	registry:                 ^wl.registry,
	compositor:               ^wl.compositor,
	layer_shell:              ^wl.layer_shell_v1,
	surface:                  ^wl.surface,
	layer_surface:            ^wl.layer_surface_v1,
	egl_window:               ^wl.egl_window,
	egl_display:              EGLDisplay,
	egl_config:               EGLConfig,
	egl_surface:              EGLSurface,
	egl_context:              EGLContext,
	font_face:                FT_Face,
	serial:                   u32,
	width:                    u32,
	height:                   u32,
	program:                  u32,
	vbo:                      u32,
	text_program:             u32,
	text_vbo:                 u32,
	resolution_location:      i32,
	color_location:           i32,
	text_position_location:   i32,
	text_uv_location:         i32,
	text_resolution_location: i32,
	text_color_location:      i32,
	text_texture_location:    i32,
	rect_position_location:   i32,
	rect_size_location:       i32,
	rect_radius_location:     i32,
	configured:               bool,
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
