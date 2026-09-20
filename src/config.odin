package main

import "core:encoding/json"
import "core:fmt"
import "core:os"

CONFIG_FILE_PATH :: "/home/drspliff/.config/oshell/config.json"
Config :: struct {
	excluded_notification_log_appnames: []string,
	font_filepath:                      string,
	font_size:                          FT_UInt,
	allow_notification_logging:         bool,
	fullscreen_output_switching:        bool,
	allow_infinite_marquee:             bool,
}

config_create :: proc() -> bool {
	if !os.exists(os.dir(CONFIG_FILE_PATH)) {
		e := os.make_directory_all(os.dir(CONFIG_FILE_PATH))
		if e != nil {
			fmt.eprintfln("Failed to create Config Directory: %v", e)
			return false
		}
	}

	default_config := Config {
		excluded_notification_log_appnames = {
			"nhc",
			"nohistory",
			"nh-center-text",
			"ts",
			"theme_selector",
		},
		font_filepath                      = DEFAULT_FONT_PATH,
		font_size                          = DEFAULT_FONT_SIZE,
		fullscreen_output_switching        = true,
		allow_infinite_marquee             = true,
		allow_notification_logging         = true,
	}
	b, e := json.marshal(default_config)
	if e != nil {
		fmt.eprintfln("Failed to marshal default Config data: %v", e)
		return false
	}
	defer delete(b)

	err := os.write_entire_file_from_bytes(CONFIG_FILE_PATH, b)
	if err != nil {
		fmt.eprintfln("Failed to write default Config file: %v", err)
		return false
	}

	return true
}

config_load :: proc(app: ^App) {
	b, e := os.read_entire_file_from_path(CONFIG_FILE_PATH, context.allocator)
	if e != nil {
		fmt.eprintfln("Failed to read Config file: %v\nSkipping config init", e)
		return
	}
	defer delete(b)

	err := json.unmarshal(b, &app.config)
	if err != nil {
		fmt.eprintfln("Failed to unmarshal Config file:%v\nSkipping config init", err)
		return
	}

	app.config_initialised = true
	if DEBUG do fmt.printfln("Loaded config file: %s", CONFIG_FILE_PATH)
}

config_init :: proc(app: ^App) {
	if !os.exists(CONFIG_FILE_PATH) {
		if ok := config_create(); !ok {
			fmt.eprintfln("Skipping config init")
			return
		}
	}
	config_load(app)
}

config_reload :: proc(app: ^App) {
	app.config_initialised = false
	config_destroy(app)
	config_load(app)

	if !app_reload_font(app) do fmt.eprintfln("Failed to reload configured font")
}

config_destroy :: proc(app: ^App) {
	if !app.config_initialised do return
	if len(app.config.font_filepath) > 0 do delete_string(app.config.font_filepath)

	for t in app.config.excluded_notification_log_appnames do delete_string(t)
	delete(app.config.excluded_notification_log_appnames)
}
