package main

import "base:runtime"
import "core:c"
import libc "core:c/libc"
import "core:fmt"
import "core:strings"
import "core:sys/posix"

MPRIS_PREFIX :: "org.mpris.MediaPlayer2."
MPRIS_PATH :: "/org/mpris/MediaPlayer2"
MPRIS_PLAYER :: "org.mpris.MediaPlayer2.Player"
DBUS_PROPERTIES :: "org.freedesktop.DBus.Properties"

MPRIS_PROPERTIES_MATCH :: "type='signal',path='/org/mpris/MediaPlayer2',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged'"

MPRIS_NAME_OWNER_MATCH :: "type='signal',sender='org.freedesktop.DBus',interface='org.freedesktop.DBus',member='NameOwnerChanged'"

Media_Snapshot :: struct {
	player:     [MEDIA_PLAYER_CAPACITY]u8,
	player_len: int,
	title:      [MEDIA_TITLE_CAPACITY]u8,
	title_len:  int,
	playing:    bool,
}

media_snapshot :: proc(media: ^Media_State) -> Media_Snapshot {
	snapshot: Media_Snapshot

	snapshot.player_len = media.player_len
	snapshot.title_len = media.title_len
	snapshot.playing = media.playing

	if snapshot.player_len > 0 do copy(snapshot.player[:snapshot.player_len], media.player[:snapshot.player_len])

	if snapshot.title_len > 0 do copy(snapshot.title[:snapshot.title_len], media.title[:snapshot.title_len])

	return snapshot
}

media_changed :: proc(media: ^Media_State, snapshot: ^Media_Snapshot) -> bool {
	if media.playing != snapshot.playing do return true
	if media.player_len != snapshot.player_len do return true
	if media.title_len != snapshot.title_len do return true

	if media.player_len > 0 {
		old_player := string(snapshot.player[:snapshot.player_len])
		if media_get_player(media) != old_player do return true
	}

	if media.title_len > 0 {
		old_title := string(snapshot.title[:snapshot.title_len])
		if media_get_title(media) != old_title do return true
	}

	return false
}

media_is_mpris_player :: proc(name: string) -> bool {return strings.has_prefix(name, MPRIS_PREFIX)}

// sd_bus_list_names() transfers ownership of both the array and every string inside it
media_free_names :: proc(names: [^]cstring) {
	if names == nil do return
	i := 0
	for names[i] != nil {
		libc.free(cast(rawptr)names[i])
		i += 1
	}
	libc.free(cast(rawptr)names)
}


// Query org.mpris.MediaPlayer2.Player.PlaybackStatus.
media_player_is_playing :: proc(media: ^Media_State, player: cstring) -> bool {
	reply: ^sd_bus_message
	error: sd_bus_error

	result := sd_bus_get_property(
		media.bus,
		player,
		MPRIS_PATH,
		MPRIS_PLAYER,
		"PlaybackStatus",
		&error,
		&reply,
		"s",
	)

	defer sd_bus_error_free(&error)

	if result < 0 do return false
	if reply == nil do return false

	defer sd_bus_message_unref(reply)

	status: cstring
	result = sd_bus_message_read_basic(reply, SD_BUS_TYPE_STRING, &status)

	if result <= 0 do return false
	if status == nil do return false

	return string(status) == "Playing"
}


media_load_metadata :: proc(media: ^Media_State, player: cstring) -> bool {
	media_clear_artist(media)
	media_clear_title(media)

	reply: ^sd_bus_message
	error: sd_bus_error

	result := sd_bus_get_property(
		media.bus,
		player,
		MPRIS_PATH,
		MPRIS_PLAYER,
		"Metadata",
		&error,
		&reply,
		"a{sv}",
	)

	defer sd_bus_error_free(&error)

	if result < 0 do return false
	if reply == nil do return false

	defer sd_bus_message_unref(reply)

	result = sd_bus_message_enter_container(reply, SD_BUS_TYPE_ARRAY, "{sv}")

	if result <= 0 do return false

	for {
		result = sd_bus_message_enter_container(reply, SD_BUS_TYPE_DICT_ENTRY, "sv")

		if result < 0 do return false
		if result == 0 do break

		key: cstring

		result = sd_bus_message_read_basic(reply, SD_BUS_TYPE_STRING, &key)

		if result <= 0 do return false

		value_type: u8
		value_contents: cstring

		result = sd_bus_message_peek_type(reply, &value_type, &value_contents)

		if result <= 0 do return false

		if value_type != SD_BUS_TYPE_VARIANT {
			sd_bus_message_exit_container(reply)
			continue
		}

		result = sd_bus_message_enter_container(reply, SD_BUS_TYPE_VARIANT, value_contents)

		if result <= 0 do return false

		key_string := ""

		if key != nil {
			key_string = string(key)
		}

		if key_string == "xesam:title" {
			title: cstring

			result = sd_bus_message_read_basic(reply, SD_BUS_TYPE_STRING, &title)

			if result > 0 && title != nil {
				media_set_title(media, string(title))
			}

		} else if key_string == "xesam:artist" {
			result = sd_bus_message_enter_container(reply, SD_BUS_TYPE_ARRAY, "s")

			if result > 0 {
				artist: cstring

				result = sd_bus_message_read_basic(reply, SD_BUS_TYPE_STRING, &artist)

				if result > 0 && artist != nil {
					media_set_artist(media, string(artist))
				}

				// Consume any remaining artists.
				for {
					other: cstring

					result = sd_bus_message_read_basic(reply, SD_BUS_TYPE_STRING, &other)

					if result <= 0 do break
				}

				sd_bus_message_exit_container(reply)
			}

		} else if value_contents != nil {
			sd_bus_message_skip(reply, value_contents)
		}

		sd_bus_message_exit_container(reply)
		sd_bus_message_exit_container(reply)
	}

	sd_bus_message_exit_container(reply)

	if DEBUG {
		fmt.println("metadata artist:", media_get_artist(media), "title:", media_get_title(media))
	}

	return media.title_len > 0
}


media_refresh :: proc(app: ^App) -> (bool, bool) {
	media := &app.media

	if media.bus == nil do return false, false
	before := media_snapshot(media)

	names: [^]cstring

	result := sd_bus_list_names(media.bus, &names, nil)
	if result < 0 {
		fmt.eprintln("Media: Failed to list D-Bus names:", result)
		return false, false
	}
	defer media_free_names(names)

	current := media_get_player(media)
	if current != "" {
		i := 0
		for names[i] != nil {
			name := string(names[i])

			if name == current {
				if media_player_is_playing(media, names[i]) {
					media.playing = true
					media_load_metadata(media, names[i])
					changed := media_changed(media, &before)
					if DEBUG && changed {
						fmt.println("media:", current, "-", media_get_title(media))
					}
					return changed, true
				}

				break
			}
			i += 1
		}
	}

	i := 0
	for names[i] != nil {
		name := string(names[i])

		if !media_is_mpris_player(name) {
			i += 1
			continue
		}

		if !media_player_is_playing(media, names[i]) {
			i += 1
			continue
		}

		media_set_player(media, name)
		media.playing = true
		media_load_metadata(media, names[i])
		changed := media_changed(media, &before)
		if DEBUG && changed {
			fmt.println("media:", media_get_player(media), "-", media_get_title(media))
		}
		return changed, true
	}

	media_clear_playback(media)
	changed := media_changed(media, &before)
	if DEBUG && changed do fmt.println("media: nothing playing")
	return changed, true
}


// D-Bus match callback.
media_signal :: proc "c" (
	message: ^sd_bus_message,
	userdata: rawptr,
	error: ^sd_bus_error,
) -> c.int {
	context = runtime.default_context()

	app := cast(^App)userdata
	context.user_ptr = app
	app.media.dirty = true

	return 0
}


media_init :: proc(app: ^App) -> bool {
	media := &app.media

	media_state_init(media)
	result := sd_bus_open_user(&media.bus)
	if result < 0 {
		fmt.eprintln("Media: Failed to connect to session D-Bus:", result)
		return false
	}

	media.fd = posix.FD(sd_bus_get_fd(media.bus))
	if media.fd < 0 {
		fmt.eprintln("Media: Failed to get D-Bus fd")
		media_destroy(app)
		return false
	}

	result = sd_bus_add_match(
		media.bus,
		&media.properties_slot,
		MPRIS_PROPERTIES_MATCH,
		media_signal,
		app,
	)

	if result < 0 {
		fmt.eprintln("Media: Failed to add PropertiesChanged match:", result)
		media_destroy(app)
		return false
	}

	result = sd_bus_add_match(
		media.bus,
		&media.name_owner_slot,
		MPRIS_NAME_OWNER_MATCH,
		media_signal,
		app,
	)

	if result < 0 {
		fmt.eprintln("Media: Failed to add NameOwnerChanged match:", result)
		media_destroy(app)
		return false
	}

	if sd_bus_flush(media.bus) < 0 {
		fmt.eprintln("Media: Failed to flush D-Bus")
		media_destroy(app)
		return false
	}

	_, refresh_ok := media_refresh(app)

	if !refresh_ok {
		fmt.eprintln("Media: Failed initial refresh")
		media_destroy(app)
		return false
	}

	if DEBUG do fmt.println("connected to media D-Bus")

	return true
}


media_process :: proc(app: ^App) -> bool {
	media := &app.media

	if media.bus == nil do return true

	for {
		result := sd_bus_process(media.bus, nil)
		if result < 0 {
			fmt.eprintln("Media: D-Bus processing failed:", result)
			return false
		}
		if result == 0 do break
	}

	if media.dirty {
		media.dirty = false
		changed, ok := media_refresh(app)
		if !ok do return false
		if changed {
			media_reset_scroll(media)
			request_redraw_all(app)
		}
	}

	return true
}


media_destroy :: proc(app: ^App) {
	media := &app.media

	if media.properties_slot != nil {
		sd_bus_slot_unref(media.properties_slot)
		media.properties_slot = nil
	}

	if media.name_owner_slot != nil {
		sd_bus_slot_unref(media.name_owner_slot)
		media.name_owner_slot = nil
	}

	if media.bus != nil {
		sd_bus_unref(media.bus)
		media.bus = nil
	}

	media.fd = posix.FD(-1)
	media_clear_playback(media)
	media.dirty = false
}
