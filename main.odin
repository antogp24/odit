package odit 
import "core:fmt"
import "core:math"
import "core:strings"
import "core:c/libc"
import rl "vendor:raylib"

DEBUG :: false

font_size := i32(24)

Line :: struct {
    number: int,
    text: [dynamic]u8
}

CursorPos :: [2]int

Buffer :: struct {
    is_selection_active: bool,
    select: CursorPos,
    cursor: CursorPos,
    lines: [dynamic]Line
}

string_to_u8_dyn :: proc(text: string) -> [dynamic]u8 {
    result := make([dynamic]u8)
    for c in text {
        append(&result, u8(c))
    }
    return result
}

alias_as_cstring :: proc(text: [dynamic]u8) -> cstring {
    return strings.unsafe_string_to_cstring(transmute(string)text[:])
}

copy_to_cstring :: proc(text: [dynamic]u8, alloc := context.temp_allocator) -> cstring {
    return strings.clone_to_cstring(transmute(string)text[:], alloc)
}

get_font_dimentions :: proc(font: ^rl.Font) -> (width, height: f32) {
    mz := rl.MeasureTextEx(font^, "a", f32(font_size), 0)
    width, height = mz.x, mz.y
    return 
}

timers := map[rl.KeyboardKey]f32 {
    .BACKSPACE = 0.0,
    .ENTER     = 0.0,
    .UP        = 0.0,
    .DOWN      = 0.0,
    .LEFT      = 0.0,
    .RIGHT     = 0.0,
}

timer_update :: proc(key: rl.KeyboardKey, dt: f32) {
    if rl.IsKeyDown(key) {
        timers[key] += dt
    } else {
        timers[key] = 0
    }
}

// https://www.geogebra.org/calculator
// Square wave function that returns values between 0 and 1
oscilate :: proc (x, period: f32) -> bool {
    using math
    result := -floor(sin(x * PI / period))
    return bool(int(result))
}

key_is_pressed_or_down :: proc(pressed, key: rl.KeyboardKey, threshold: f32 = 0.3) -> bool {
    return pressed == key || (timers[key] > threshold && oscilate(timers[key], 0.015))
}

press_backspace :: proc(using buffer: ^Buffer) {
    if cursor.x == 0 && cursor.y == 0 {
        return
    }
    else if cursor.x == 0  && cursor.y - 1 >= 0 {
        whole_line := lines[cursor.y].text[:]
        if len(lines) >= 1 {
            ordered_remove(&lines, cursor.y)
        }
        cursor.y -= 1
        cursor.x = len(lines[cursor.y].text)
        append(&lines[cursor.y].text, ..whole_line)
        for i := cursor.y + 1; i < len(lines); i += 1 {
            lines[i].number -= 1
        }
    }
    else if len(lines[cursor.y].text) > 0 {
        if cursor.x - 1 >= 0 {
            cursor.x -= 1
        }
        ordered_remove(&lines[cursor.y].text, cursor.x)
    }
}

press_enter :: proc(using buffer: ^Buffer) {
    line_number := cursor.y + 1
    if cursor.y + 1 != len(lines) {
        line_number = cursor.y
    }

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

    inject_at(&lines, cursor.y, Line{line_number, make([dynamic]u8)})

    if enter_before_end {
        append(&lines[cursor.y].text, ..text_to_copy[:])
    }

    if cursor.y + 1 != len(lines) {
        for i := cursor.y; i < len(lines); i += 1 {
            lines[i].number += 1
        }
    }
}

move_cursor_up :: proc(using buffer: ^Buffer) {
    if cursor.y - 1 >= 0 {
        cursor.y -= 1
        if cursor.x > len(lines[cursor.y].text) {
            cursor.x = len(lines[cursor.y].text)
        }
    }
}

move_cursor_down :: proc(using buffer: ^Buffer) {
    if cursor.y + 1 < len(lines) {
        cursor.y += 1
        if cursor.x > len(lines[cursor.y].text) {
            cursor.x = len(lines[cursor.y].text)
        }
    }
}

move_cursor_left :: proc(using buffer: ^Buffer) {
    if cursor.x - 1 >= 0 {
        cursor.x -= 1
    }
    else if cursor.y - 1 >= 0 {
        cursor.y -= 1
        cursor.x = len(lines[cursor.y].text)
    }
}

move_cursor_right :: proc(using buffer: ^Buffer) {
    if len(lines) == 0 do return
    if cursor.x + 1 <= len(lines[cursor.y].text) {
        cursor.x += 1
    }
    else if cursor.y + 1 < len(lines) {
        cursor.x = 0
        cursor.y += 1
    }
}

get_selection_boundaries :: proc(using buffer: ^Buffer) -> (start, end: CursorPos) {
    if !is_selection_active do return

    if select.x < cursor.x {
        start.x = select.x
        end.x = cursor.x
    }
    else {
        start.x = cursor.x
        end.x = select.x
    }
    if select.y < cursor.y {
        start.y = select.y
        end.y = cursor.y
    }
    else {
        start.y = cursor.y
        end.y = select.y
    }
    return start, end
}

main :: proc() {
    rl.SetTargetFPS(60)
    rl.SetConfigFlags({.MSAA_4X_HINT, .WINDOW_RESIZABLE})
    rl.InitWindow(600, 400, "Odit")
    defer rl.CloseWindow()

    font := rl.LoadFontEx("assets/UbuntuMono-Regular.ttf", i32(font_size), nil, 0)
    buffer: Buffer
    buffer.lines = make([dynamic]Line, 0, 50)

    for !rl.WindowShouldClose() {

        dt := rl.GetFrameTime()
        char := i32(rl.GetCharPressed())

        // Typing into the buffer.
        if (char >= ' ' && char <= '~') && !(rl.IsKeyDown(.LEFT_CONTROL) || rl.IsKeyDown(.LEFT_ALT)) {
            using buffer
            if len(lines) == 0 {
                append(&lines, Line{0, make([dynamic]u8)})
            }
            inject_at(&lines[cursor.y].text, cursor.x, u8(char))
            cursor.x += 1
            buffer.is_selection_active = false
        }

        // Updating the time the movement keys have been held.
        for key in timers {
            timer_update(key, dt)
        }

        key := rl.GetKeyPressed()

        if key_is_pressed_or_down(key, .BACKSPACE) {
            press_backspace(&buffer)
            buffer.is_selection_active = false
        }

        if key_is_pressed_or_down(key, .ENTER) {
            press_enter(&buffer)
            buffer.is_selection_active = false
        }
        
        if key_is_pressed_or_down(key, .UP) {
            move_cursor_up(&buffer)
        }

        if key_is_pressed_or_down(key, .DOWN) {
            move_cursor_down(&buffer)
        }

        if key_is_pressed_or_down(key, .LEFT) {
            move_cursor_left(&buffer)
        }

        if key_is_pressed_or_down(key, .RIGHT) {
            move_cursor_right(&buffer)
        }

        // Scaling the font. Very expensive operation.
        if rl.IsKeyPressed(.EQUAL) && rl.IsKeyDown(.LEFT_CONTROL) {
            font_size += 1
            rl.UnloadFont(font)
            font = rl.LoadFontEx("assets/UbuntuMono-Regular.ttf", i32(font_size), nil, 0)
        }
        else if rl.IsKeyPressed(.MINUS) && rl.IsKeyDown(.LEFT_CONTROL) {
            font_size -= 1
            rl.UnloadFont(font)
            font = rl.LoadFontEx("assets/UbuntuMono-Regular.ttf", i32(font_size), nil, 0)
        }

        // Moving the selection.
        {
            using buffer
            pressed_movement_keys := key == .UP || key == .DOWN || key == .LEFT || key == .RIGHT

            if !is_selection_active && rl.IsKeyDown(.LEFT_SHIFT) && pressed_movement_keys {
                is_selection_active = true
                select.x, select.y = cursor.x, cursor.y
            }
            else if is_selection_active && !rl.IsKeyDown(.LEFT_SHIFT) && pressed_movement_keys {
                is_selection_active = false
            }
        }

        rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)
        {
            using buffer

            // Cursor
            width, height := get_font_dimentions(&font)
            rl.DrawRectangleRec(rl.Rectangle{f32(cursor.x)*width, f32(cursor.y)*height, width, height}, rl.GREEN)

            // Buffer text
            when DEBUG do fmt.println("---------------------")
            start, end := get_selection_boundaries(&buffer)
            for _, i in lines {
                when DEBUG do fmt.println(lines[i].number, ":", transmute(string)lines[i].text[:])
                text := copy_to_cstring(lines[i].text)
                pos := rl.Vector2{0, f32(lines[i].number*cast(int)font_size)}
                rl.DrawTextEx(font, text, pos, f32(font_size), 0, rl.WHITE)

                if is_selection_active {
                    rl.DrawText(rl.TextFormat("start: %i, %i", start.x, start.y), 300, 0, 30, rl.WHITE)
                    rl.DrawText(rl.TextFormat("end  : %i, %i", end.x, end.y), 300, 30, 30, rl.WHITE)
                }
            }
            free_all(context.temp_allocator)
            when DEBUG do fmt.println("---------------------")

            when DEBUG {
                if len(lines) > 0 {
                    rl.DrawText(rl.TextFormat("len(text): %i", i32(len(lines[cursor.y].text))), 400, 0, 30, rl.WHITE)
                }
                rl.DrawText(rl.TextFormat("len(lines): %i", i32(len(lines))), 400, 30, 30, rl.WHITE)
                rl.DrawText(rl.TextFormat("cursor: %i, %i", i32(cursor.x), i32(cursor.y)), 400, 60, 30, rl.WHITE)
            }
        }
        rl.EndDrawing()
    }
}
