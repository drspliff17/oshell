//+build linux
package main

import "core:fmt"
import posix "core:sys/posix"

g_reload_colours: b32 = false
g_exit_requested: b32 = false

handle_sigusr1 :: proc "c" (sig: posix.Signal) {g_reload_colours = true}

handle_exit_signal :: proc "c" (sig: posix.Signal) {g_exit_requested = true}

setup_signals :: proc() {
	usr1_handler := posix.signal(.SIGUSR1, handle_sigusr1)

	if rawptr(usr1_handler) == posix.SIG_ERR {
		fmt.eprintln("Failed to install SIGUSR1 handler")
		return
	}

	int_handler := posix.signal(.SIGINT, handle_exit_signal)

	if rawptr(int_handler) == posix.SIG_ERR {
		fmt.eprintln("Failed to install SIGINT handler")
		return
	}

	term_handler := posix.signal(.SIGTERM, handle_exit_signal)

	if rawptr(term_handler) == posix.SIG_ERR {
		fmt.eprintln("Failed to install SIGTERM handler")
		return
	}

	if posix.siginterrupt(.SIGUSR1, true) != .OK do fmt.eprintln("Failed to configure SIGUSR1 interrupt behaviour")
	if posix.siginterrupt(.SIGINT, true) != .OK do fmt.eprintln("Failed to configure SIGINT interrupt behaviour")
	if posix.siginterrupt(.SIGTERM, true) != .OK do fmt.eprintln("Failed to configure SIGTERM interrupt behaviour")
}
