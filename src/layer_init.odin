package main

import "core:fmt"

app_init_primary_layer :: proc(app: ^App) -> ^Layer {
	output := app_preferred_output(app)
	if output == nil {
		fmt.eprintln("No preferred output available")
		return nil
	}
	if DEBUG {
		if output == app.hdmi_output {
			fmt.println("using output: HDMI-A-1")
		} else {
			fmt.println("using output: eDP-1")
		}
	}

	layer := app_create_layer(app, output)
	if layer == nil {
		fmt.eprintln("Failed to create initial layer")
		return nil
	}
	app.output_mode = .Preferred
	if DEBUG do fmt.println("configured:", layer.width, layer.height)
	return layer
}
