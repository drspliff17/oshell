package main

import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"
import "core:sys/posix"

volume_refresh :: proc(app: ^App) -> (changed: bool, ok: bool) {
	volume := &app.volume

	state, stdout, stderr, err := os.process_exec(
		os.Process_Desc{command = []string{"wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"}},
		context.allocator,
	)
	defer delete(stdout)
	defer delete(stderr)

	if err != os.ERROR_NONE {
		fmt.eprintln("Volume: Failed to execute wpctl:", os.error_string(err))
		return false, false
	}

	if !state.exited || state.exit_code != 0 {
		if len(stderr) > 0 do fmt.eprintln("Volume: wpctl failed:", string(stderr))
		return false, false
	}

	output := string(stdout)
	volume_prefix :: "Volume: "

	if !strings.has_prefix(output, volume_prefix) {
		fmt.eprintln("Volume: Unexpected wpctl output:", output)
		return false, false
	}

	value, _, parsed := strconv.parse_f32_prefix(output[len(volume_prefix):])

	if !parsed {
		fmt.eprintln("Volume: Failed to parse wpctl output:", output)
		return false, false
	}

	percent := int(value * 100.0 + 0.5)
	muted := strings.contains(output, "[MUTED]")
	changed = !volume.available || volume.percent != percent || volume.muted != muted

	volume.percent = percent
	volume.muted = muted
	volume.available = true

	if DEBUG && changed do fmt.println("volume:", volume.percent, "muted:", volume.muted)
	return changed, true
}

volume_init :: proc(app: ^App) -> bool {
	volume := &app.volume
	volume_state_init(volume)

	read_pipe, write_pipe, pipe_err := os.pipe()
	if pipe_err != os.ERROR_NONE {
		fmt.eprintln("Volume: Failed to create subscription pipe:", os.error_string(pipe_err))
		return false
	}

	process, process_err := os.process_start(
		os.Process_Desc{command = []string{"pactl", "subscribe"}, stdout = write_pipe},
	)

	os.close(write_pipe)

	if process_err != os.ERROR_NONE {
		fmt.eprintln("Volume: Failed to start pactl subscribe:", os.error_string(process_err))
		os.close(read_pipe)
		return false
	}

	volume.process = process
	volume.pipe = read_pipe
	volume.fd = posix.FD(os.fd(read_pipe))

	_, refresh_ok := volume_refresh(app)

	if !refresh_ok {
		fmt.eprintln("Volume: Failed initial volume refresh")
		volume_destroy(app)
		return false
	}

	if DEBUG do fmt.println("connected to volume events:", volume.percent, "%")
	return true
}

volume_process :: proc(app: ^App) -> bool {
	volume := &app.volume
	if volume.pipe == nil do return true

	refresh := false

	for {
		has_data, pipe_err := os.pipe_has_data(volume.pipe)
		if pipe_err != os.ERROR_NONE {
			fmt.eprintln("Volume: Subscription pipe failed:", os.error_string(pipe_err))
			return false
		}
		if !has_data do break

		buffer: [1024]u8
		n, read_err := os.read(volume.pipe, buffer[:])

		if read_err != os.ERROR_NONE {
			fmt.eprintln("Volume: Failed to read subscription:", os.error_string(read_err))
			return false
		}
		if n <= 0 do break
		if volume.buffer_len + n > len(volume.buffer) do volume.buffer_len = 0

		copy(volume.buffer[volume.buffer_len:volume.buffer_len + n], buffer[:n])
		volume.buffer_len += n
	}

	start := 0
	for i := 0; i < volume.buffer_len; i += 1 {
		if volume.buffer[i] != '\n' do continue
		line := string(volume.buffer[start:i])
		if strings.contains(line, " on sink ") || strings.contains(line, " on server ") do refresh = true
		start = i + 1
	}

	if start > 0 {
		remaining := volume.buffer_len - start
		for i in 0 ..< remaining do volume.buffer[i] = volume.buffer[start + i]
		volume.buffer_len = remaining
	}
	if !refresh do return true

	changed, refresh_ok := volume_refresh(app)
	if !refresh_ok do return false

	if changed do request_redraw_all(app)
	return true
}

volume_destroy :: proc(app: ^App) {
	volume := &app.volume

	if volume.process.pid != 0 {
		_ = os.process_kill(volume.process)
		_, _ = os.process_wait(volume.process)
		volume.process = {}
	}

	if volume.pipe != nil {
		_ = os.close(volume.pipe)
		volume.pipe = nil
	}

	volume.fd = posix.FD(-1)
	volume.buffer_len = 0
	volume.percent = 0
	volume.muted = false
	volume.available = false
}
