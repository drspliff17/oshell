package main

import "base:runtime"
import "core:c"
import "core:fmt"
import "core:sys/posix"

NOTIFICATIONS_SERVICE :: "org.freedesktop.Notifications"
NOTIFICATIONS_PATH :: "/org/freedesktop/Notifications"
NOTIFICATIONS_INTERFACE :: "org.freedesktop.Notifications"

notifications_send_reply :: proc(message: ^sd_bus_message, reply: ^sd_bus_message) -> c.int {
	bus := sd_bus_message_get_bus(message)
	if bus == nil do return -1

	result := sd_bus_send(bus, reply, nil)
	if result < 0 do return result

	return 1
}

notifications_reply_empty :: proc(message: ^sd_bus_message) -> c.int {
	reply: ^sd_bus_message

	result := sd_bus_message_new_method_return(message, &reply)

	if result < 0 do return result
	defer sd_bus_message_unref(reply)

	return notifications_send_reply(message, reply)
}

notifications_reply_id :: proc(message: ^sd_bus_message, id: u32) -> c.int {
	reply: ^sd_bus_message

	result := sd_bus_message_new_method_return(message, &reply)

	if result < 0 do return result
	defer sd_bus_message_unref(reply)

	reply_id := id
	result = sd_bus_message_append_basic(reply, SD_BUS_TYPE_UINT32, &reply_id)
	if result < 0 do return result

	return notifications_send_reply(message, reply)
}

notifications_reply_capabilities :: proc(message: ^sd_bus_message) -> c.int {
	reply: ^sd_bus_message

	result := sd_bus_message_new_method_return(message, &reply)

	if result < 0 do return result
	defer sd_bus_message_unref(reply)

	result = sd_bus_message_open_container(reply, SD_BUS_TYPE_ARRAY, "s")
	if result < 0 do return result

	result = sd_bus_message_close_container(reply)
	if result < 0 do return result

	return notifications_send_reply(message, reply)
}

notifications_reply_server_information :: proc(message: ^sd_bus_message) -> c.int {
	reply: ^sd_bus_message

	result := sd_bus_message_new_method_return(message, &reply)

	if result < 0 do return result
	defer sd_bus_message_unref(reply)

	name: cstring = "oshell"
	vendor: cstring = "oshell"
	version: cstring = "0.1"
	spec_version: cstring = "1.3"

	result = sd_bus_message_append_basic(reply, SD_BUS_TYPE_STRING, rawptr(name))
	if result < 0 do return result

	result = sd_bus_message_append_basic(reply, SD_BUS_TYPE_STRING, rawptr(vendor))
	if result < 0 do return result

	result = sd_bus_message_append_basic(reply, SD_BUS_TYPE_STRING, rawptr(version))
	if result < 0 do return result

	result = sd_bus_message_append_basic(reply, SD_BUS_TYPE_STRING, rawptr(spec_version))
	if result < 0 do return result

	return notifications_send_reply(message, reply)
}

notifications_handle_notify :: proc(app: ^App, message: ^sd_bus_message) -> c.int {
	app_name: cstring
	replaces_id: u32
	app_icon: cstring
	summary: cstring
	body: cstring
	expire_timeout: i32

	result := sd_bus_message_read_basic(message, SD_BUS_TYPE_STRING, &app_name)
	if result < 0 do return result

	result = sd_bus_message_read_basic(message, SD_BUS_TYPE_UINT32, &replaces_id)
	if result < 0 do return result

	result = sd_bus_message_read_basic(message, SD_BUS_TYPE_STRING, &app_icon)
	if result < 0 do return result

	result = sd_bus_message_read_basic(message, SD_BUS_TYPE_STRING, &summary)
	if result < 0 do return result

	result = sd_bus_message_read_basic(message, SD_BUS_TYPE_STRING, &body)
	if result < 0 do return result

	result = sd_bus_message_skip(message, "as")
	if result < 0 do return result

	result = sd_bus_message_skip(message, "a{sv}")
	if result < 0 do return result

	result = sd_bus_message_read_basic(message, SD_BUS_TYPE_INT32, &expire_timeout)
	if result < 0 do return result

	id := replaces_id
	if id == 0 {
		id = app.notifications.next_id
		app.notifications.next_id += 1
		if app.notifications.next_id == 0 do app.notifications.next_id = 1
	}

	if DEBUG {
		fmt.println("notification:", id)
		fmt.println("  app:", app_name)
		fmt.println("  icon:", app_icon)
		fmt.println("  summary:", summary)
		fmt.println("  body:", body)
		fmt.println("  timeout:", expire_timeout)
	}

	return notifications_reply_id(message, id)
}

notifications_handle_close :: proc(message: ^sd_bus_message) -> c.int {
	id: u32

	result := sd_bus_message_read_basic(message, SD_BUS_TYPE_UINT32, &id)
	if result < 0 do return result

	if DEBUG do fmt.println("notification close:", id)
	return notifications_reply_empty(message)
}

notifications_message_handler :: proc "c" (
	message: ^sd_bus_message,
	userdata: rawptr,
	error: ^sd_bus_error,
) -> c.int {
	context = runtime.default_context()

	app := cast(^App)userdata
	context.user_ptr = app

	if sd_bus_message_is_method_call(message, NOTIFICATIONS_INTERFACE, "Notify") > 0 do return notifications_handle_notify(app, message)

	if sd_bus_message_is_method_call(message, NOTIFICATIONS_INTERFACE, "CloseNotification") > 0 do return notifications_handle_close(message)

	if sd_bus_message_is_method_call(message, NOTIFICATIONS_INTERFACE, "GetCapabilities") > 0 do return notifications_reply_capabilities(message)

	if sd_bus_message_is_method_call(message, NOTIFICATIONS_INTERFACE, "GetServerInformation") > 0 do return notifications_reply_server_information(message)

	return 0
}

notifications_init :: proc(app: ^App) -> bool {
	state := &app.notifications
	notification_state_init(state)

	result := sd_bus_open_user(&state.bus)

	if result < 0 {
		fmt.eprintln("Notifications: Failed to open user bus:", result)
		return false
	}

	result = sd_bus_add_object(
		state.bus,
		&state.slot,
		NOTIFICATIONS_PATH,
		notifications_message_handler,
		app,
	)

	if result < 0 {
		fmt.eprintln("Notifications: Failed to register object:", result)
		notifications_destroy(app)
		return false
	}

	result = sd_bus_request_name(state.bus, NOTIFICATIONS_SERVICE, 0)
	if result < 0 {
		fmt.eprintln("Notifications: Failed to claim org.freedesktop.Notifications:", result)
		notifications_destroy(app)
		return false
	}

	fd := sd_bus_get_fd(state.bus)
	if fd < 0 {
		fmt.eprintln("Notifications: Failed to get bus fd:", fd)
		notifications_destroy(app)
		return false
	}

	state.fd = posix.FD(fd)
	if DEBUG do fmt.println("connected to notification events")
	return true
}

notifications_process :: proc(app: ^App) -> bool {
	state := &app.notifications
	if state.bus == nil do return true

	for {
		result := sd_bus_process(state.bus, nil)
		if result < 0 {
			fmt.eprintln("Notifications: Failed to process bus:", result)
			return false
		}
		if result == 0 do break
	}

	result := sd_bus_flush(state.bus)
	if result < 0 {
		fmt.eprintln("Notifications: Failed to flush bus:", result)
		return false
	}

	return true
}

notifications_destroy :: proc(app: ^App) {
	state := &app.notifications

	if state.bus != nil do _ = sd_bus_release_name(state.bus, NOTIFICATIONS_SERVICE)
	if state.slot != nil do state.slot = sd_bus_slot_unref(state.slot)
	if state.bus != nil do state.bus = sd_bus_unref(state.bus)
	state.fd = posix.FD(-1)
	state.next_id = 1
}
