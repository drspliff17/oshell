package main

import "core:c"

foreign import systemd "system:systemd"

// Opaque libsystemd types.
sd_bus :: struct {}
sd_bus_slot :: struct {}
sd_bus_message :: struct {}

sd_bus_error :: struct {
	name:       cstring,
	message:    cstring,
	_need_free: c.int,
}

// Callback used by sd_bus_add_match.
sd_bus_message_handler_t :: proc "c" (
	message: ^sd_bus_message,
	userdata: rawptr,
	error: ^sd_bus_error,
) -> c.int


SD_BUS_TYPE_BYTE :: u8('y')
SD_BUS_TYPE_BOOLEAN :: u8('b')
SD_BUS_TYPE_INT16 :: u8('n')
SD_BUS_TYPE_UINT16 :: u8('q')
SD_BUS_TYPE_INT32 :: u8('i')
SD_BUS_TYPE_UINT32 :: u8('u')
SD_BUS_TYPE_INT64 :: u8('x')
SD_BUS_TYPE_UINT64 :: u8('t')
SD_BUS_TYPE_DOUBLE :: u8('d')
SD_BUS_TYPE_STRING :: u8('s')
SD_BUS_TYPE_OBJECT_PATH :: u8('o')
SD_BUS_TYPE_SIGNATURE :: u8('g')
SD_BUS_TYPE_UNIX_FD :: u8('h')
SD_BUS_TYPE_ARRAY :: u8('a')
SD_BUS_TYPE_VARIANT :: u8('v')
SD_BUS_TYPE_STRUCT :: u8('r')
SD_BUS_TYPE_STRUCT_BEGIN :: u8('(')
SD_BUS_TYPE_STRUCT_END :: u8(')')
SD_BUS_TYPE_DICT_ENTRY :: u8('e')
SD_BUS_TYPE_DICT_ENTRY_BEGIN :: u8('{')
SD_BUS_TYPE_DICT_ENTRY_END :: u8('}')

@(default_calling_convention = "c")
foreign systemd {

	// Connection

	sd_bus_open_user :: proc(ret: ^^sd_bus) -> c.int ---
	sd_bus_unref :: proc(bus: ^sd_bus) -> ^sd_bus ---
	sd_bus_get_fd :: proc(bus: ^sd_bus) -> c.int ---
	sd_bus_get_events :: proc(bus: ^sd_bus) -> c.int ---
	sd_bus_get_timeout :: proc(bus: ^sd_bus, timeout_usec: ^u64) -> c.int ---
	sd_bus_process :: proc(bus: ^sd_bus, ret_message: ^^sd_bus_message) -> c.int ---
	sd_bus_flush :: proc(bus: ^sd_bus) -> c.int ---

	// Match / signal handling

	sd_bus_add_match :: proc(bus: ^sd_bus, slot: ^^sd_bus_slot, match: cstring, callback: sd_bus_message_handler_t, userdata: rawptr) -> c.int ---
	sd_bus_slot_unref :: proc(slot: ^sd_bus_slot) -> ^sd_bus_slot ---

	// Bus names

	sd_bus_list_names :: proc(bus: ^sd_bus, acquired: ^[^]cstring, activatable: ^[^]cstring) -> c.int ---
	sd_bus_request_name :: proc(bus: ^sd_bus, name: cstring, flags: u64) -> c.int ---
	sd_bus_release_name :: proc(bus: ^sd_bus, name: cstring) -> c.int ---

	// Property access

	sd_bus_get_property :: proc(bus: ^sd_bus, destination: cstring, path: cstring, interface: cstring, member: cstring, error: ^sd_bus_error, reply: ^^sd_bus_message, expected_type: cstring) -> c.int ---

	// Objects

	sd_bus_add_object :: proc(bus: ^sd_bus, slot: ^^sd_bus_slot, path: cstring, callback: sd_bus_message_handler_t, userdata: rawptr) -> c.int ---

	// Message lifetime

	sd_bus_message_unref :: proc(message: ^sd_bus_message) -> ^sd_bus_message ---

	// Message inspection

	sd_bus_message_get_sender :: proc(message: ^sd_bus_message) -> cstring ---
	sd_bus_message_get_path :: proc(message: ^sd_bus_message) -> cstring ---
	sd_bus_message_get_interface :: proc(message: ^sd_bus_message) -> cstring ---
	sd_bus_message_get_member :: proc(message: ^sd_bus_message) -> cstring ---
	sd_bus_message_get_signature :: proc(message: ^sd_bus_message, complete: c.int) -> cstring ---
	sd_bus_message_is_method_call :: proc(message: ^sd_bus_message, interface: cstring, member: cstring) -> c.int ---
	sd_bus_message_get_bus :: proc(message: ^sd_bus_message) -> ^sd_bus ---

	// Message reading

	sd_bus_message_read_basic :: proc(message: ^sd_bus_message, kind: u8, ret: rawptr) -> c.int ---
	sd_bus_message_enter_container :: proc(message: ^sd_bus_message, kind: u8, contents: cstring) -> c.int ---
	sd_bus_message_exit_container :: proc(message: ^sd_bus_message) -> c.int ---
	sd_bus_message_peek_type :: proc(message: ^sd_bus_message, ret_type: ^u8, ret_contents: ^cstring) -> c.int ---
	sd_bus_message_skip :: proc(message: ^sd_bus_message, types: cstring) -> c.int ---
	sd_bus_message_at_end :: proc(message: ^sd_bus_message, complete: c.int) -> c.int ---
	sd_bus_message_rewind :: proc(message: ^sd_bus_message, complete: c.int) -> c.int ---

	// Reply Construction
	sd_bus_message_new_method_return :: proc(call: ^sd_bus_message, reply: ^^sd_bus_message) -> c.int ---
	sd_bus_message_append_basic :: proc(message: ^sd_bus_message, kind: u8, value: rawptr) -> c.int ---
	sd_bus_message_open_container :: proc(message: ^sd_bus_message, kind: u8, contents: cstring) -> c.int ---
	sd_bus_message_close_container :: proc(message: ^sd_bus_message) -> c.int ---
	sd_bus_send :: proc(bus: ^sd_bus, message: ^sd_bus_message, cookie: ^u64) -> c.int ---

	// Error handling

	sd_bus_error_free :: proc(error: ^sd_bus_error) ---
}
