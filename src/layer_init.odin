package main

import "core:fmt"

app_init_primary_layers :: proc(app: ^App) -> ^Layer {
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

	bar := app_create_layer(app, output, .Bar)

	if bar == nil {
		fmt.eprintln("Failed to create initial bar layer")
		return nil
	}

	notification := app_create_layer(app, output, .Notification)
	if notification == nil {
		fmt.eprintln("Failed to create initial notification layer")
		app_destroy_layers(app)
		return nil
	}

	app.output_mode = .Preferred

	if DEBUG {
		fmt.println("bar configured:", bar.width, bar.height)
		fmt.println("notification configured:", notification.width, notification.height)
	}
	return bar
}
