//+build linux
package main

import "core:fmt"
import posix "core:sys/posix"

g_reload_colours: b32 = false

handle_sigusr1 :: proc "c" (sig: posix.Signal) {
	g_reload_colours = true
}

setup_signals :: proc() {
	handler := posix.signal(.SIGUSR1, handle_sigusr1)

	if rawptr(handler) == posix.SIG_ERR {
		fmt.eprintln("Failed to install SIGUSR1 handler")
		return
	}

	if posix.siginterrupt(.SIGUSR1, true) != .OK {
		fmt.eprintln("Failed to configure SIGUSR1 interrupt behaviour")
	}
}
