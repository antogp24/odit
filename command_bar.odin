package odit

import "core:os"
import "core:fmt"
import "core:strings"

get_command_names :: proc() -> (names: [dynamic]string) {
	names = make([dynamic]string, context.temp_allocator)
	file, ok := os.read_entire_file("actions.odin")
	if !ok do panic("Couldn't load file actions.odin")

	line_has_proc :: proc(line: string) -> bool {
		for i := 0; i + 4 < len(line); i += 1 {
			if strings.compare(transmute(string)line[i:i+4], "proc") == 0 do return true
		}
		return false
	}

	get_name :: proc(line: string) -> string {
		for i := 0; i < len(line); i += 1 {
			if line[i] == ' ' do return line[:i]
		}
		return ""
	}

	actions := transmute(string)file
	for i, start : int; i < len(actions); i += 1 {
		if !(actions[i] == 0 || actions[i] == '\n') do continue
		line := actions[start:i]
		start = i + 1
		if !line_has_proc(line) do continue
		name := get_name(line)
		append(&names, name)
	}
	fmt.println(names)
	return
}