package main

import "core:fmt"

app_init_hyprland :: proc(app: ^App) -> bool {
	if !hyprland_connect(&app.hypr) {
		fmt.eprintln("Hyprland IPC unavailable")
		return false
	}
	return true
}

app_destroy_hyprland :: proc(app: ^App) {hyprland_disconnect(&app.hypr)}
