package main

import "core:fmt"
import "core:os"
import "core:strings"
import "core:sys/posix"

Oshell_IPC :: struct {
	fd:       posix.FD,
	path:     [512]u8,
	path_len: int,
}

oshell_ipc_init :: proc(app: ^App) -> bool {
	ipc := &app.ipc

	ipc.fd = posix.FD(-1)

	runtime_buf: [4096]u8
	runtime_dir := os.get_env_buf(runtime_buf[:], "XDG_RUNTIME_DIR")

	if runtime_dir == "" {
		fmt.eprintln("oshell IPC: XDG_RUNTIME_DIR is not set")
		return false
	}

	path := fmt.bprintf(ipc.path[:], "%s/oshell.sock", runtime_dir)
	ipc.path_len = len(path)
	fd := posix.socket(.UNIX, .STREAM)

	if fd < 0 {
		fmt.eprintln("oshell IPC: Failed to create socket")
		return false
	}

	addr: posix.sockaddr_un
	addr.sun_family = .UNIX

	if len(path) >= len(addr.sun_path) {
		fmt.eprintln("oshell IPC: Socket path is too long")
		posix.close(fd)
		return false
	}

	copy(addr.sun_path[:], path)

	posix.unlink(cast(cstring)&ipc.path[0])
	if posix.bind(fd, cast(^posix.sockaddr)&addr, posix.socklen_t(size_of(addr))) != .OK {
		fmt.eprintln("oshell IPC: Failed to bind socket")
		posix.close(fd)
		return false
	}

	if posix.listen(fd, 8) != .OK {
		fmt.eprintln("oshell IPC: Failed to listen")
		posix.close(fd)
		posix.unlink(cast(cstring)&ipc.path[0])
		return false
	}

	ipc.fd = fd
	if DEBUG do fmt.println("oshell IPC:", path)
	return true
}

oshell_ipc_destroy :: proc(app: ^App) {
	ipc := &app.ipc

	if ipc.fd >= 0 {
		posix.close(ipc.fd)
		ipc.fd = posix.FD(-1)
	}

	if ipc.path_len > 0 {
		posix.unlink(cast(cstring)&ipc.path[0])
		ipc.path_len = 0
	}
}

oshell_ipc_execute :: proc(app: ^App, command: string) -> bool {
	command := command
	command = strings.trim_space(command)

	parts := strings.split(command, " ")
	defer delete(parts)

	switch parts[0] {
	case "output", "monitor", "m":
		if len(parts) < 1 do return false
		switch parts[1] {
		case "preferred", "1":
			return app_set_output_mode(app, .Preferred)

		case "inverted", "2":
			return app_set_output_mode(app, .Inverted)

		case "all", "3":
			return app_set_output_mode(app, .All)

		case "hide", "h":
			return app_set_output_mode(app, .Hide)

		case "toggle", "t":
			return app_toggle_output(app)

		case:
			return false
		}

	case "redraw", "r":
		request_redraw_all(app)
		return true

	case "quit", "q":
		app.exit_requested = true
		return true

	case "ping":
		return true
	}

	if DEBUG do fmt.println("oshell IPC: unknown command:", command)
	return false
}

oshell_ipc_handle :: proc(app: ^App) -> bool {
	client := posix.accept(app.ipc.fd, nil, nil)
	if client < 0 do return false
	defer posix.close(client)

	buffer: [256]u8
	bytes_read := posix.read(client, &buffer[0], uint(len(buffer)))
	if bytes_read <= 0 do return true

	command := string(buffer[:bytes_read])
	if DEBUG do fmt.println("oshell IPC command:", strings.trim_space(command))

	ok := oshell_ipc_execute(app, command)

	reply_buf: [16]u8
	reply := "ok\n"

	if !ok do reply = "error\n"

	copy(reply_buf[:], reply)
	posix.write(client, &reply_buf[0], uint(len(reply)))

	return true
}
