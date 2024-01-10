package odit

import "core:os"
import "core:strings"
import "core:strconv"
import "core:fmt"
import rl "vendor:raylib"

Command_Bar :: struct {
    active: bool,
    cursor: int,
    error_t: f32,
    text: [dynamic]u8,
}

command_bar := Command_Bar{false, 0, 0, make([dynamic]u8)}

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
	return
}

command_bar_error_out :: proc() {
    clear(&command_bar.text)
    command_bar.cursor = 0
    command_bar.error_t = 1.5
}

command_bar_execute :: proc(buffer: ^Buffer, _command: string) {
    arguments := strings.split(_command, " ")
    command := arguments[0]

    if command == "press_backspace" {
        press_backspace(buffer)
    } else if command == "delete_selection" {
        delete_selection(buffer)
    } else if command == "press_enter" {
        press_enter(buffer)
    } else if command == "move_cursor_up" {
        move_cursor_up(buffer)
    } else if command == "move_cursor_down" {
        move_cursor_down(buffer)
    } else if command == "move_cursor_left" {
        move_cursor_left(buffer)
    } else if command == "move_cursor_right" {
        move_cursor_right(buffer)
    } else if command == "move_cursor_end" {
        move_cursor_end(buffer)
    } else if command == "move_cursor_home" {
        move_cursor_home(buffer)
    } else if command == "move_cursor_home_non_whitespace" {
        move_cursor_home_non_whitespace(buffer)
    } else if command == "goto_end_of_file" {
        goto_end_of_file(buffer)
    } else if command == "goto_start_of_file" {
        goto_start_of_file(buffer)
    } else if command == "font_size" && len(arguments) == 3 {
        number, ok := strconv.parse_int(arguments[2])
        if !ok do command_bar_error_out()
        if ok {
            if arguments[1] == "+" {
                font_size += f32(number)
            } else if arguments[1] == "-" {
                font_size -= f32(number)
            }
            font_size = clamp(font_size, FONT_SIZE_MIN, FONT_SIZE_MAX)
            rl.UnloadFont(font)
            font = rl.LoadFontEx("assets/UbuntuMono-Regular.ttf", i32(font_size), nil, 0)
        } 
    } else {
        command_bar_error_out()
    }
    reset_selection(buffer)
}
