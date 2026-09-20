package main

import "base:runtime"
import "core:c"
import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:sys/posix"
import "core:time"
import wl "wayland"

NOTIFICATIONS_SERVICE :: "org.freedesktop.Notifications"
NOTIFICATIONS_PATH :: "/org/freedesktop/Notifications"
NOTIFICATIONS_INTERFACE :: "org.freedesktop.Notifications"

NOTIFICATION_LOG_PATH :: "/home/drspliff/dev/data/notifications.jsonl"

Notification_Log_Entry :: struct {
	timestamp: string,
	appname:   string,
	summary:   string,
	body:      string,
}

notification_log :: proc(appname: string, summary: string, body: string) -> bool {
	app := get_app()
	for t in app.config.excluded_notification_log_appnames do if t == appname do return true

	now := time.now()

	year, month, day := time.date(now)
	hour, minute, second := time.clock_from_time(now)

	timestamp_buf: [32]u8
	timestamp := fmt.bprintf(
		timestamp_buf[:],
		"%02d/%02d/%04d:%02d:%02d:%02d",
		day,
		int(month),
		year,
		hour + 1,
		minute,
		second,
	)

	entry := Notification_Log_Entry {
		timestamp = timestamp,
		appname   = appname,
		summary   = summary,
		body      = body,
	}

	data, marshal_err := json.marshal(entry)
	if marshal_err != nil {
		fmt.eprintln("Notifications: Failed to encode log entry:", marshal_err)
		return false
	}
	defer delete(data)

	file, open_err := os.open(NOTIFICATION_LOG_PATH, os.O_WRONLY | os.O_APPEND | os.O_CREATE)
	if open_err != nil {
		fmt.eprintln("Notifications: Failed to open log:", open_err)
		return false
	}
	defer os.close(file)

	_, write_err := os.write(file, data)
	if write_err != nil {
		fmt.eprintln("Notifications: Failed to write log:", write_err)
		return false
	}

	_, newline_err := os.write_string(file, "\n")
	if newline_err != nil {
		fmt.eprintln("Notifications: Failed to finish log entry:", newline_err)
		return false
	}

	return true
}

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

notifications_find :: proc(state: ^Notification_State, id: u32) -> int {
	for i in 0 ..< len(state.items) do if state.items[i].id == id do return i
	return -1
}

notification_find_view :: proc(notification: ^Notification, output: ^wl.output) -> ^Layer {
	for view in notification.views do if view.output == output do return view
	return nil
}

notification_set_appname :: proc(notification: ^Notification, appname: string) {
	appname_len := min(len(appname), len(notification.appname))
	if appname_len > 0 do copy(notification.appname[:appname_len], appname[:appname_len])
	notification.appname_len = appname_len
}

notification_set_text :: proc(notification: ^Notification, summary: string, body: string) {
	summary_len := min(len(summary), len(notification.summary))
	body_len := min(len(body), len(notification.body))

	if summary_len > 0 do copy(notification.summary[:summary_len], summary[:summary_len])
	if body_len > 0 do copy(notification.body[:body_len], body[:body_len])

	notification.summary_len = summary_len
	notification.body_len = body_len
}

notification_set_timeout :: proc(notification: ^Notification, expire_timeout: i32) {
	notification.started_at = time.tick_now()

	if expire_timeout == 0 {
		notification.expires = false
		notification.timeout = 0
		return
	}

	notification.expires = true
	if expire_timeout < 0 {
		notification.timeout = NOTIFICATION_DEFAULT_TIMEOUT
		return
	}

	notification.timeout = time.Duration(i64(expire_timeout) * 1_000_000)
}

notification_measure_size :: proc(
	app: ^App,
	output: ^wl.output,
	notification: ^Notification,
) -> (
	u32,
	u32,
) {
	measure_layer := app_find_layer(app, output)

	if measure_layer == nil {
		if len(app.layers) == 0 do return 1, 1
		measure_layer = app.layers[0]
	}

	if measure_layer.egl_surface == nil do return 1, 1
	if !layer_make_current(measure_layer) do return 1, 1

	font_size := app_get_font_size(app)

	summary := notification_get_summary(notification)
	body := notification_get_body(notification)

	summary_metrics := measure_text(measure_layer, summary, font_size)
	body_metrics := measure_text(measure_layer, body, font_size)

	line_metrics := measure_text(measure_layer, "Hg", font_size)
	line_height := line_metrics.ascent + line_metrics.descent

	content_width := max(summary_metrics.width, body_metrics.width)

	width := min(content_width + f32(NOTIFICATION_PADDING_X * 2), f32(NOTIFICATION_MAX_WIDTH))
	height := line_height + f32(NOTIFICATION_PADDING_Y * 2)

	if body != "" do height = line_height * 2 + f32(NOTIFICATION_TEXT_GAP) + f32(NOTIFICATION_PADDING_Y * 2)

	if width < 1 do width = 1
	if height < 1 do height = 1

	return u32(width + 0.5), u32(height + 0.5)
}

notification_create_view :: proc(
	app: ^App,
	notification: ^Notification,
	output: ^wl.output,
) -> ^Layer {
	if output == nil do return nil

	existing := notification_find_view(notification, output)
	if existing != nil do return existing

	width, height := notification_measure_size(app, output, notification)

	view := new(Layer)

	view.app = app
	view.layer_type = .Notification
	view.notification_id = notification.id
	view.notification_width = width
	view.notification_height = height
	view.margin_left = 10
	view.margin_top = 10

	if !layer_create_surface(view, output) {
		free(view)
		return nil
	}

	if notification.views == nil do notification.views = make([dynamic]^Layer)
	append(&notification.views, view)
	return view
}

notification_create_views :: proc(app: ^App, notification: ^Notification) {
	if app.output_mode == .Hide do return

	for bar in app.layers {
		if bar.output == nil do continue
		if bar.surface == nil do continue
		if bar.egl_surface == nil do continue

		_ = notification_create_view(app, notification, bar.output)
	}
}

notification_destroy_views :: proc(notification: ^Notification) {
	for view in notification.views {
		layer_destroy_surface(view)
		free(view)
	}

	if notification.views != nil {
		delete(notification.views)
		notification.views = nil
	}
}

notification_recreate_views :: proc(app: ^App, notification: ^Notification) {
	notification_destroy_views(notification)
	notification_create_views(app, notification)
}

notifications_remove :: proc(app: ^App, index: int) {
	state := &app.notifications
	if index < 0 || index >= len(state.items) do return

	notification := &state.items[index]
	notification_destroy_views(notification)
	ordered_remove(&state.items, index)
}

notifications_relayout_output :: proc(app: ^App, output: ^wl.output) {
	if output == nil do return

	bar := app_find_layer(app, output)

	if bar == nil do return
	if !bar.configured do return

	margin := 10
	gap := 8

	x := margin
	y := margin
	row_height := 0

	for i in 0 ..< len(app.notifications.items) {
		notification := &app.notifications.items[i]

		view := notification_find_view(notification, output)
		if view == nil do continue

		width := int(view.notification_width)
		height := int(view.notification_height)

		if x > margin && x + width > int(bar.width) - margin {
			x = margin
			y += row_height + gap
			row_height = 0
		}

		layer_set_position(view, x, y)

		x += width + gap
		row_height = max(row_height, height)
	}
}

notifications_relayout :: proc(app: ^App) {
	for bar in app.layers {
		if bar.output == nil do continue
		if !bar.configured do continue
		notifications_relayout_output(app, bar.output)
	}
}

notifications_request_redraw :: proc(app: ^App) {
	for i in 0 ..< len(app.notifications.items) {
		notification := &app.notifications.items[i]
		for view in notification.views do request_redraw(view)
	}
}

notifications_sync_outputs :: proc(app: ^App) {
	for i in 0 ..< len(app.notifications.items) {
		notification := &app.notifications.items[i]
		notification_destroy_views(notification)
		notification_create_views(app, notification)
	}

	notifications_relayout(app)
	notifications_request_redraw(app)
}

notifications_next_timeout :: proc(app: ^App) -> (i32, bool) {
	state := &app.notifications

	found := false
	nearest: time.Duration

	for i in 0 ..< len(state.items) {
		notification := &state.items[i]
		if !notification.expires do continue

		elapsed := time.tick_since(notification.started_at)
		remaining := notification.timeout - elapsed
		if remaining <= 0 do return 0, true

		if !found || remaining < nearest {
			nearest = remaining
			found = true
		}
	}

	if !found do return 0, false

	timeout := int(time.duration_milliseconds(nearest))
	if timeout < 1 do timeout = 1
	return i32(timeout), true
}

notifications_tick :: proc(app: ^App) {
	state := &app.notifications
	changed := false

	i := 0
	for i < len(state.items) {
		notification := &state.items[i]
		if !notification.expires {
			i += 1
			continue
		}

		if time.tick_since(notification.started_at) < notification.timeout {
			i += 1
			continue
		}

		if DEBUG do fmt.println("notification expired:", notification.id)
		notifications_remove(app, i)
		changed = true
	}

	if changed {
		notifications_relayout(app)
		notifications_request_redraw(app)
	}
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

	appname_text := string(app_name)
	summary_text := string(summary)
	body_text := string(body)

	if app.config.allow_notification_logging do notification_log(string(app_name), string(summary), string(body))

	id: u32
	index := -1

	if replaces_id != 0 do index = notifications_find(&app.notifications, replaces_id)

	if index >= 0 {
		id = replaces_id

		notification := &app.notifications.items[index]

		notification_set_appname(notification, appname_text)
		notification_set_text(notification, summary_text, body_text)
		notification_set_timeout(notification, expire_timeout)
		notification_recreate_views(app, notification)

		notifications_relayout(app)

		for view in notification.views do request_redraw(view)
	} else {
		id = app.notifications.next_id

		app.notifications.next_id += 1
		if app.notifications.next_id == 0 do app.notifications.next_id = 1

		notification := Notification {
			id = id,
		}

		notification_set_appname(&notification, appname_text)
		notification_set_text(&notification, summary_text, body_text)
		notification_set_timeout(&notification, expire_timeout)

		append(&app.notifications.items, notification)

		new_notification := &app.notifications.items[len(app.notifications.items) - 1]

		notification_create_views(app, new_notification)
		notifications_relayout(app)

		for view in new_notification.views do request_redraw(view)
	}

	if DEBUG {
		fmt.println("notification:", id)
		fmt.println("  app:", appname_text)
		fmt.println("  icon:", app_icon)
		fmt.println("  summary:", summary_text)
		fmt.println("  body:", body_text)
		fmt.println("  timeout:", expire_timeout)
	}

	return notifications_reply_id(message, id)
}

notifications_handle_close :: proc(app: ^App, message: ^sd_bus_message) -> c.int {
	id: u32

	result := sd_bus_message_read_basic(message, SD_BUS_TYPE_UINT32, &id)
	if result < 0 do return result
	if DEBUG do fmt.println("notification close:", id)

	index := notifications_find(&app.notifications, id)
	if index >= 0 {
		notifications_remove(app, index)
		notifications_relayout(app)
		notifications_request_redraw(app)
	}

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
	if sd_bus_message_is_method_call(message, NOTIFICATIONS_INTERFACE, "CloseNotification") > 0 do return notifications_handle_close(app, message)
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

	for len(state.items) > 1 do notifications_remove(app, len(state.items) - 1)
	if state.bus != nil do _ = sd_bus_release_name(state.bus, NOTIFICATIONS_SERVICE)
	if state.slot != nil do state.slot = sd_bus_slot_unref(state.slot)
	if state.bus != nil do state.bus = sd_bus_unref(state.bus)
	if state.items != nil {
		delete(state.items)
		state.items = nil
	}
	state.fd = posix.FD(-1)
	state.next_id = 1
}
