#+build linux

package wayland

layer_shell_v1_layer :: enum i32 {
	background = 0,
	bottom     = 1,
	top        = 2,
	overlay    = 3,
}

layer_surface_v1_anchor :: enum i32 {
	top    = 1,
	bottom = 2,
	left   = 4,
	right  = 8,
}

layer_surface_v1_keyboard_interactivity :: enum i32 {
	none      = 0,
	exclusive = 1,
	on_demand = 2,
}

layer_shell_v1 :: struct {
	_: proxy,
}

layer_surface_v1 :: struct {
	_: proxy,
}

layer_shell_v1_interface: interface
layer_surface_v1_interface: interface

wlr_layer_shell_types := []^interface {
	&layer_surface_v1_interface,
	&surface_interface,
	&output_interface,
	nil,
	nil,
}

layer_shell_v1_requests := []message {
	{"get_layer_surface", "no?ous", raw_data(wlr_layer_shell_types)},
	{"destroy", "", nil},
}

layer_surface_v1_requests := []message {
	{"set_size", "uu", nil},
	{"set_anchor", "u", nil},
	{"set_exclusive_zone", "i", nil},
	{"set_margin", "iiii", nil},
	{"set_keyboard_interactivity", "u", nil},
	{"get_popup", "o", nil},
	{"ack_configure", "u", nil},
	{"destroy", "", nil},
	{"set_layer", "u", nil},
}

layer_surface_v1_events := []message{{"configure", "uuu", nil}, {"closed", "", nil}}

@(init)
init_layer_shell_interfaces :: proc "contextless" () {
	layer_shell_v1_interface.name = "zwlr_layer_shell_v1"
	layer_shell_v1_interface.version = 1
	layer_shell_v1_interface.method_count = 2
	layer_shell_v1_interface.methods = raw_data(layer_shell_v1_requests)

	layer_surface_v1_interface.name = "zwlr_layer_surface_v1"
	layer_surface_v1_interface.version = 1
	layer_surface_v1_interface.method_count = 9
	layer_surface_v1_interface.methods = raw_data(layer_surface_v1_requests)
	layer_surface_v1_interface.event_count = 2
	layer_surface_v1_interface.events = raw_data(layer_surface_v1_events)
}

layer_shell_v1_get_layer_surface :: proc "contextless" (
	shell: ^layer_shell_v1,
	surface: ^surface,
	output: ^output,
	layer: layer_shell_v1_layer,
	namespace: cstring,
) -> ^layer_surface_v1 {
	ret := proxy_marshal_flags(
		cast(^proxy)shell,
		0,
		&layer_surface_v1_interface,
		proxy_get_version(cast(^proxy)shell),
		0,
		nil,
		surface,
		output,
		layer,
		namespace,
	)

	return cast(^layer_surface_v1)ret
}

layer_shell_v1_destroy :: proc "contextless" (shell: ^layer_shell_v1) {
	proxy_marshal_flags(cast(^proxy)shell, 1, nil, proxy_get_version(cast(^proxy)shell), 1)
}

layer_surface_v1_set_size :: proc "contextless" (
	surface: ^layer_surface_v1,
	width: u32,
	height: u32,
) {
	proxy_marshal(cast(^proxy)surface, 0, width, height)
}

layer_surface_v1_set_anchor :: proc "contextless" (
	surface: ^layer_surface_v1,
	anchor: layer_surface_v1_anchor,
) {
	proxy_marshal(cast(^proxy)surface, 1, anchor)
}

layer_surface_v1_set_exclusive_zone :: proc "contextless" (surface: ^layer_surface_v1, zone: i32) {
	proxy_marshal(cast(^proxy)surface, 2, zone)
}

layer_surface_v1_set_margin :: proc "contextless" (
	surface: ^layer_surface_v1,
	top: i32,
	right: i32,
	bottom: i32,
	left: i32,
) {
	proxy_marshal(cast(^proxy)surface, 3, top, right, bottom, left)
}

layer_surface_v1_set_keyboard_interactivity :: proc "contextless" (
	surface: ^layer_surface_v1,
	interactivity: layer_surface_v1_keyboard_interactivity,
) {
	proxy_marshal(cast(^proxy)surface, 4, interactivity)
}

layer_surface_v1_get_popup :: proc "contextless" (surface: ^layer_surface_v1, popup: ^proxy) {
	proxy_marshal(cast(^proxy)surface, 5, popup)
}

layer_surface_v1_ack_configure :: proc "contextless" (surface: ^layer_surface_v1, serial: u32) {
	proxy_marshal(cast(^proxy)surface, 6, serial)
}

layer_surface_v1_destroy :: proc "contextless" (surface: ^layer_surface_v1) {
	proxy_marshal_flags(cast(^proxy)surface, 7, nil, proxy_get_version(cast(^proxy)surface), 1)
}

layer_surface_v1_set_layer :: proc "contextless" (
	surface: ^layer_surface_v1,
	layer: layer_shell_v1_layer,
) {
	proxy_marshal(cast(^proxy)surface, 8, layer)
}

layer_surface_v1_listener :: struct {
	configure: proc "c" (
		data: rawptr,
		surface: ^layer_surface_v1,
		serial: u32,
		width: u32,
		height: u32,
	),
	closed:    proc "c" (data: rawptr, surface: ^layer_surface_v1),
}

layer_surface_v1_add_listener :: proc "contextless" (
	surface: ^layer_surface_v1,
	listener: ^layer_surface_v1_listener,
	data: rawptr,
) {
	proxy_add_listener(cast(^proxy)surface, cast(^generic_c_call)listener, data)
}
