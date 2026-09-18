package main
import "core:fmt"
import "core:time"

test_output_modes :: proc(app: ^App, cycles: int = 5, dwell: time.Duration = 2 * time.Second) {
	if len(app.layers) == 0 do return

	layer := app.layers[0]

	for cycle := 0; cycle < cycles; cycle += 1 {
		if DEBUG do fmt.println("TEST: cycle", cycle + 1, "-", "Preferred")

		if !app_set_output_mode(app, .Preferred) {
			fmt.eprintln("TEST: failed to set Preferred")
			return
		}

		run_event_loop(layer, dwell)

		if DEBUG do fmt.println("TEST: cycle", cycle + 1, "-", "Inverted")

		if !app_set_output_mode(app, .Inverted) {
			fmt.eprintln("TEST: failed to set Inverted")
			return
		}

		run_event_loop(layer, dwell)

		if DEBUG do fmt.println("TEST: cycle", cycle + 1, "-", "All")

		if !app_set_output_mode(app, .All) {
			fmt.eprintln("TEST: failed to set All")
			return
		}

		run_event_loop(layer, dwell)
	}

	if DEBUG do fmt.println("TEST: restoring Preferred")

	if !app_set_output_mode(app, .Preferred) {
		fmt.eprintln("TEST: failed to restore Preferred")
		return
	}

	run_event_loop(layer, dwell)

	if DEBUG do fmt.println("TEST: output mode stress test complete")
}
