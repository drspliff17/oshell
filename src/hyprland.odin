//+build linux
package main

import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"
import "core:sys/posix"

Hyprland_State :: struct {
	workspaces:       [dynamic]int,
	submap:           [128]u8,
	submap_len:       int,
	active_workspace: int,
}

Hyprland_IPC :: struct {
	buffer:         [8192]u8,
	state:          Hyprland_State,
	fd:             posix.FD,
	length:         int,
	redraw_pending: bool,
}

Hyprctl_Workspace :: struct {
	id: int,
}

Hyprctl_Active_Workspace :: struct {
	id: int,
}

hyprland_set_submap :: proc(state: ^Hyprland_State, submap: string) {
	state.submap_len = min(len(submap), len(state.submap))
	copy(state.submap[:state.submap_len], submap[:state.submap_len])
}

hyprland_get_submap :: proc(state: ^Hyprland_State) -> string {
	return string(state.submap[:state.submap_len])
}

hyprland_has_workspace :: proc(state: ^Hyprland_State, id: int) -> bool {
	for workspace in state.workspaces do if workspace == id do return true
	return false
}

hyprland_add_workspace :: proc(state: ^Hyprland_State, id: int) {
	if id <= 0 do return
	if hyprland_has_workspace(state, id) do return
	append(&state.workspaces, id)

	i := len(state.workspaces) - 1
	for i > 0 && state.workspaces[i] < state.workspaces[i - 1] {
		state.workspaces[i], state.workspaces[i - 1] = state.workspaces[i - 1], state.workspaces[i]
		i -= 1
	}
}

hyprland_remove_workspace :: proc(state: ^Hyprland_State, id: int) {
	for workspace, i in state.workspaces {
		if workspace != id do continue
		ordered_remove(&state.workspaces, i)
		return
	}
}

hyprctl :: proc(args: []string) -> ([]u8, bool) {
	command := make([]string, len(args) + 1)
	defer delete(command)

	command[0] = "hyprctl"
	copy(command[1:], args)
	process, stdout, stderr, err := os.process_exec(
		os.Process_Desc{command = command},
		context.allocator,
	)
	defer delete(stderr)

	if err != nil || !process.success {
		delete(stdout)
		return nil, false
	}

	return stdout, true
}

hyprland_load_initial_state :: proc(ipc: ^Hyprland_IPC) -> bool {
	ipc.state.workspaces = make([dynamic]int)

	// Workspaces
	workspace_data, workspace_ok := hyprctl([]string{"-j", "workspaces"})
	if !workspace_ok {
		fmt.eprintln("Hyprland IPC: Failed to query workspaces")
		return false
	}
	defer delete(workspace_data)

	workspaces: []Hyprctl_Workspace
	if err := json.unmarshal(workspace_data, &workspaces); err != nil {
		fmt.eprintln("Hyprland IPC: Failed to parse workspaces")
		return false
	}
	defer delete(workspaces)

	for workspace in workspaces do hyprland_add_workspace(&ipc.state, workspace.id)

	// Active workspace
	active_data, active_ok := hyprctl([]string{"-j", "activeworkspace"})
	if !active_ok {
		fmt.eprintln("Hyprland IPC: Failed to query active workspace")
		return false
	}
	defer delete(active_data)

	active: Hyprctl_Active_Workspace
	if err := json.unmarshal(active_data, &active); err != nil {
		fmt.eprintln("Hyprland IPC: Failed to parse active workspace")
		return false
	}
	ipc.state.active_workspace = active.id

	// Submap
	submap_data, submap_ok := hyprctl([]string{"submap"})
	if !submap_ok {
		fmt.eprintln("Hyprland IPC: Failed to query submap")
		return false
	}
	defer delete(submap_data)

	hyprland_set_submap(&ipc.state, strings.trim_space(string(submap_data)))

	if DEBUG {
		fmt.println("workspaces:", ipc.state.workspaces[:])
		fmt.println("active workspace:", ipc.state.active_workspace)
		fmt.println("submap:", hyprland_get_submap(&ipc.state))
	}
	return true
}

hyprland_connect :: proc(ipc: ^Hyprland_IPC) -> bool {
	ipc.fd = posix.FD(-1)

	runtime_buf: [4096]u8
	signature_buf: [4096]u8

	runtime_dir := os.get_env_buf(runtime_buf[:], "XDG_RUNTIME_DIR")
	signature := os.get_env_buf(signature_buf[:], "HYPRLAND_INSTANCE_SIGNATURE")

	if runtime_dir == "" {
		fmt.eprintln("Hyprland IPC: XDG_RUNTIME_DIR is not set")
		return false
	}

	if signature == "" {
		fmt.eprintln("Hyprland IPC: HYPRLAND_INSTANCE_SIGNATURE is not set")
		return false
	}

	path_buf: [512]u8
	path := fmt.bprintf(path_buf[:], "%s/hypr/%s/.socket2.sock", runtime_dir, signature)

	fd := posix.socket(.UNIX, .STREAM)
	if fd < 0 {
		fmt.eprintln("Hyprland IPC: Failed to create socket")
		return false
	}

	addr: posix.sockaddr_un
	addr.sun_family = .UNIX

	if len(path) >= len(addr.sun_path) {
		fmt.eprintln("Hyprland IPC: Socket path is too long")
		posix.close(fd)
		return false
	}

	copy(addr.sun_path[:], path)

	if posix.connect(fd, cast(^posix.sockaddr)&addr, posix.socklen_t(size_of(addr))) != .OK {
		fmt.eprintln("Hyprland IPC: Failed to connect")
		posix.close(fd)
		return false
	}

	ipc.fd = fd

	if !hyprland_load_initial_state(ipc) {
		posix.close(fd)
		ipc.fd = posix.FD(-1)
		delete(ipc.state.workspaces)
		return false
	}

	if DEBUG do fmt.println("connected to Hyprland IPC")
	return true
}

hyprland_disconnect :: proc(ipc: ^Hyprland_IPC) {
	if ipc.fd >= 0 {
		posix.close(ipc.fd)
		ipc.fd = posix.FD(-1)
	}

	ipc.length = 0
	ipc.redraw_pending = false
	delete(ipc.state.workspaces)
}

hyprland_handle_event :: proc(layer: ^Layer, event: string) -> bool {
	event_name, separator, data := strings.partition(event, ">>")
	if separator == "" do return false

	state := &layer.hypr.state

	switch event_name {
	case "workspacev2":
		id_string, _, _ := strings.partition(data, ",")
		id, workspace_ok := strconv.parse_int(id_string)
		if !workspace_ok do return false
		state.active_workspace = id

	case "focusedmonv2":
		_, _, workspace_string := strings.partition(data, ",")
		id, focused_ok := strconv.parse_int(workspace_string)
		if !focused_ok do return false
		state.active_workspace = id

	case "createworkspacev2":
		id_string, _, _ := strings.partition(data, ",")
		id, create_ok := strconv.parse_int(id_string)
		if !create_ok do return false
		hyprland_add_workspace(state, id)

	case "destroyworkspacev2":
		id_string, _, _ := strings.partition(data, ",")
		id, destroy_ok := strconv.parse_int(id_string)
		if !destroy_ok do return false
		hyprland_remove_workspace(state, id)

	case "submap":
		if data == "" do data = "default"
		hyprland_set_submap(state, data)

	case:
		return false
	}

	if DEBUG {
		fmt.println(
			"workspaces:",
			state.workspaces[:],
			"active:",
			state.active_workspace,
			"submap:",
			hyprland_get_submap(state),
		)
	}
	return true
}

hyprland_read_events :: proc(ipc: ^Hyprland_IPC, layer: ^Layer) -> bool {
	if ipc.length >= len(ipc.buffer) {
		fmt.eprintln("Hyprland IPC: Event buffer overflow")
		ipc.length = 0
	}

	available := len(ipc.buffer) - ipc.length
	bytes_read := posix.read(ipc.fd, &ipc.buffer[ipc.length], uint(available))
	if bytes_read <= 0 do return false

	ipc.length += bytes_read
	start := 0
	changed := false

	for i := 0; i < ipc.length; i += 1 {
		if ipc.buffer[i] != '\n' do continue

		end := i
		if end > start && ipc.buffer[end - 1] == '\r' do end -= 1

		if end > start {
			event := string(ipc.buffer[start:end])
			if hyprland_handle_event(layer, event) do changed = true
		}
		start = i + 1
	}

	if start > 0 {
		remaining := ipc.length - start
		if remaining > 0 do copy(ipc.buffer[:remaining], ipc.buffer[start:ipc.length])
		ipc.length = remaining
	}

	if changed do ipc.redraw_pending = true
	return true
}
