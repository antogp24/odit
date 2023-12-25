package odit
import rl "vendor:raylib"

press_backspace :: proc(using buffer: ^Buffer) {
    if (cursor.x == 0 && cursor.y == 0) || len(lines) == 0 do return

    if cursor.x == 0  && cursor.y - 1 >= 0 {
        whole_line := lines[cursor.y].text[:]
        if len(lines) >= 1 {
            ordered_remove(&lines, cursor.y)
        }
        cursor.y -= 1
        cursor.x = len(lines[cursor.y].text)
        append(&lines[cursor.y].text, ..whole_line)
    } else if len(lines[cursor.y].text) > 0 {
        if cursor.x - 1 >= 0 {
            cursor.x -= 1
        }
        ordered_remove(&lines[cursor.y].text, cursor.x)
    }
}

delete_selection :: proc(using buffer: ^Buffer) {
    start, end := get_selection_boundaries(buffer)

    // Easiest case.
    if start.y == end.y {
        remove_range(&lines[cursor.y].text, start.x, end.x)
        cursor = start
        return
    }

    // Remove all lines in the middle.
    remove_range(&lines, start.y + 1, end.y)
    end.y = start.y + 1

    // Remove text at the boundary lines.
    remove_range(&lines[start.y].text, start.x, len(lines[start.y].text))
    remove_range(&lines[end.y].text, 0, end.x)

    // Add the remaining text from the end line to the start line.
    remaining := lines[end.y].text[:len(lines[end.y].text)]
    append(&lines[start.y].text, ..remaining)
    ordered_remove(&lines, end.y)

    cursor = start
}

press_enter :: proc(using buffer: ^Buffer) {
    if len(lines) == 0 do append(&lines, Line{make([dynamic]u8)})

    enter_before_end := cursor.x < len(lines[cursor.y].text)
    text_to_copy: [dynamic]u8
    defer if enter_before_end do free_all(context.temp_allocator)

    if enter_before_end {
        whole_line := lines[cursor.y].text[:]
        start, end := cursor.x, len(whole_line)
        text_to_copy = make([dynamic]u8, 0, end - start, context.temp_allocator)
        append(&text_to_copy, ..whole_line[start:end])
        remove_range(&lines[cursor.y].text, start, end)
    }

    cursor.x = 0
    cursor.y += 1

    inject_at(&lines, cursor.y, Line{make([dynamic]u8)})

    if enter_before_end {
        append(&lines[cursor.y].text, ..text_to_copy[:])
    }
}

move_cursor_up :: proc(using buffer: ^Buffer) {
    if !(cursor.y - 1 >= 0) do return
    cursor.y -= 1
    if cursor.x > len(lines[cursor.y].text) {
        cursor.x = len(lines[cursor.y].text)
    }
}

move_cursor_down :: proc(using buffer: ^Buffer) {
    if !(cursor.y + 1 < len(lines)) do return
    cursor.y += 1
    if cursor.x > len(lines[cursor.y].text) do cursor.x = len(lines[cursor.y].text)
}

move_cursor_left :: proc(using buffer: ^Buffer) {
    if cursor.x - 1 >= 0 {
        cursor.x -= 1
    } else if cursor.y - 1 >= 0 {
        cursor.y -= 1
        cursor.x = len(lines[cursor.y].text)
    }
}

move_cursor_right :: proc(using buffer: ^Buffer) {
    if len(lines) == 0 do return
    if cursor.x + 1 <= len(lines[cursor.y].text) {
        cursor.x += 1
    } else if cursor.y + 1 < len(lines) {
        cursor.x = 0
        cursor.y += 1
    }
}

move_cursor_end :: proc(using buffer: ^Buffer) {
    if len(lines) == 0 do return
    cursor.x = len(lines[cursor.y].text)
}

move_cursor_home :: proc(using buffer: ^Buffer) {
    if len(lines) == 0 do return
    cursor.x = 0
}

move_cursor_home_non_whitespace :: proc(using buffer: ^Buffer) {
    if len(lines) == 0 do return
    cursor.x = 0
    for char in lines[cursor.y].text {
        if cursor.x == len(lines[cursor.y].text) || char != ' ' do return
        cursor.x += 1
    }
}

goto_end_of_file :: proc(using buffer: ^Buffer) {
    if len(lines) == 0 do return
    cursor.y = len(lines)
    if cursor.x > len(lines[cursor.y].text) do cursor.x = len(lines[cursor.y].text)
}

goto_start_of_file :: proc(using buffer: ^Buffer) {
    if len(lines) == 0 do return
    cursor.x , cursor.y = 0, 0
}
