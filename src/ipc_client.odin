package main

import "core:fmt"
import "core:os"
import "core:sys/posix"

run_ipc_client :: proc(args: []string) {
	if len(args) == 0 do return

	runtime_buf: [4096]u8
	runtime_dir := os.get_env_buf(runtime_buf[:], "XDG_RUNTIME_DIR")

	if runtime_dir == "" {
		fmt.eprintln("oshell: XDG_RUNTIME_DIR is not set")
		return
	}

	path_buf: [512]u8
	path := fmt.bprintf(path_buf[:], "%s/oshell.sock", runtime_dir)

	fd := posix.socket(.UNIX, .STREAM)
	if fd < 0 {
		fmt.eprintln("oshell: failed to create IPC socket")
		return
	}
	defer posix.close(fd)

	addr: posix.sockaddr_un
	addr.sun_family = .UNIX

	if len(path) >= len(addr.sun_path) {
		fmt.eprintln("oshell: IPC socket path is too long")
		return
	}

	copy(addr.sun_path[:], path)

	if posix.connect(fd, cast(^posix.sockaddr)&addr, posix.socklen_t(size_of(addr))) != .OK {
		fmt.eprintln("oshell: could not connect to running instance")
		return
	}

	command_buf: [256]u8
	command_len := 0

	for arg, i in args {
		if i > 0 {
			if command_len >= len(command_buf) {
				fmt.eprintln("oshell: command too long")
				return
			}
			command_buf[command_len] = ' '
			command_len += 1
		}

		if command_len + len(arg) > len(command_buf) {
			fmt.eprintln("oshell: command too long")
			return
		}

		copy(command_buf[command_len:], arg)
		command_len += len(arg)
	}

	if command_len == 0 do return

	written := 0
	for written < command_len {
		n := posix.write(fd, &command_buf[written], uint(command_len - written))
		if n <= 0 {
			fmt.eprintln("oshell: failed to send command")
			return
		}
		written += n
	}

	reply: [256]u8

	bytes_read := posix.read(fd, &reply[0], uint(len(reply)))
	if bytes_read <= 0 {
		fmt.eprintln("oshell: no response")
		return
	}
	fmt.print(string(reply[:bytes_read]))
}
