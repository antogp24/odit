package odit 
import "core:fmt"
import "core:math"
import "core:strings"
import "core:c/libc"
import rl "vendor:raylib"

DEBUG :: false

CURSOR_COLOR    :: rl.GREEN
SELECTION_COLOR :: rl.BLUE

font_size := f32(24)

Line :: struct {
    text: [dynamic]u8
}

get_digit_count :: proc(number: int) -> int {
    return cast(int)math.log10_f32(cast(f32)number) + 1
}

get_line_number_width :: proc(using buffer: ^Buffer, font_width: f32) -> f32 {
    return cast(f32)get_digit_count(len(lines))*font_width
}

Buffer :: struct {
    offset: [2]f32,
    select: [2]int,
    cursor: [2]int,
    lines:  [dynamic]Line
}

is_selection_active :: proc(using buffer: ^Buffer) -> bool {
    return !(select.x == cursor.x && select.y == cursor.y)
}

reset_selection :: proc(using buffer: ^Buffer) {
    select = cursor
}

string_to_u8_dyn :: proc(text: string) -> [dynamic]u8 {
    result := make([dynamic]u8)
    for c in text {
        append(&result, u8(c))
    }
    return result
}

u8_alias_as_cstring :: proc(text: [dynamic]u8) -> cstring {
    return strings.unsafe_string_to_cstring(transmute(string)text[:])
}

u8_copy_to_cstring :: proc(text: [dynamic]u8, alloc := context.temp_allocator) -> cstring {
    return strings.clone_to_cstring(transmute(string)text[:], alloc)
}

get_font_dimentions :: proc(font: ^rl.Font) -> (width, height: f32) {
    mz := rl.MeasureTextEx(font^, "a", font_size, 0)
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
    }
    else if len(lines[cursor.y].text) > 0 {
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

move_cursor_end :: proc(using buffer: ^Buffer) {
    if len(lines) == 0 do return
    cursor.x = len(lines[cursor.y].text)
}

home_toggle := true
move_cursor_home :: proc(using buffer: ^Buffer) {
    if len(lines) == 0 do return
    cursor.x = 0
}

move_cursor_home_non_whitespace :: proc(using buffer: ^Buffer) {
    if len(lines) == 0 do return
    cursor.x = 0
    for char in lines[cursor.y].text {
        if cursor.x >= len(lines[cursor.y].text) || char != ' ' do return
        cursor.x += 1
    }
}

get_selection_boundaries :: proc(using buffer: ^Buffer) -> (start, end: [2]int) {
    if select.y == cursor.y {
        if select.x < cursor.x {
            return select, cursor
        }
        else if select.x > cursor.x {
            return cursor, select
        }
    }
    else if select.y < cursor.y {
        return select, cursor
    }
    else if select.y > cursor.y {
        return cursor, select
    }
    return
}

draw_cursor :: proc(pos: [2]int, offset: [2]f32, font_width, font_height: f32, color := CURSOR_COLOR) {
    rect := rl.Rectangle {
        offset.x + f32(pos.x)*font_width,
        offset.y + f32(pos.y)*font_height,
        font_width,
        font_height,
    }
    rl.DrawRectangleRec(rect, color)
}

draw_line_selection :: proc(using buffer: ^Buffer, i: int, _start, end: [2]int, font_width, font_height: f32) {
    rec: rl.Rectangle
    start := _start
    if cursor.x <= start.x && cursor.y == i do start.x += 1
    if start.y == end.y && i == start.y {
        rec = rl.Rectangle{f32(start.x)*font_width, f32(start.y)*font_height, f32(end.x - start.x)*font_width, font_height}
    }
    else if i == start.y {
        width := max(len(lines[i].text) - start.x, 0)
        rec = rl.Rectangle{f32(start.x)*font_width, f32(start.y)*font_height, f32(width)*font_width, font_height}
    }
    else if start.y < i && i < end.y {
        rec = rl.Rectangle{0, f32(i)*font_height, f32(len(lines[i].text))*font_width, font_height}
    }
    else if i == end.y {
        rec = rl.Rectangle{0, f32(end.y)*font_height, f32(end.x)*font_width, font_height}
    }
    if rec.width == 0 && i != cursor.y do rec.width = font_width / 4
    rec.x += offset.x
    rec.y += offset.y
    rl.DrawRectangleRec(rec, SELECTION_COLOR)
}

draw_line_number :: proc(using buffer: ^Buffer, i: int, font_width, font_height: f32, font: rl.Font) {
    rec := rl.Rectangle {
        0,
        f32(i)*font_height,
        get_line_number_width(buffer, font_width) + font_width*2,
        font_height,
    }
    pos := rl.Vector2 {
        rec.x + rec.width - font_width - cast(f32)get_digit_count(i+1)*font_width,
        rec.y,
    }
    rl.DrawRectangleRec(rec, rl.Color{20, 20, 50, 255})
    rl.DrawTextEx(font, rl.TextFormat("%i", i+1), pos, font_size, 0, rl.WHITE)
}

draw_line_text :: proc(using buffer: ^Buffer, i: int, font_size: f32, font: rl.Font) {
    text := u8_copy_to_cstring(lines[i].text)
    pos := rl.Vector2{0, f32(i)*font_size}
    pos.x += offset.x
    pos.y += offset.y
    rl.DrawTextEx(font, text, pos, font_size, 0, rl.WHITE)
}

main :: proc() {
    rl.SetTargetFPS(60)
    rl.SetConfigFlags({.MSAA_4X_HINT, .WINDOW_RESIZABLE})
    rl.InitWindow(600, 400, "Odit")
    defer rl.CloseWindow()

    camera := rl.Camera2D{}
    camera.zoom = 1

    font := rl.LoadFontEx("assets/UbuntuMono-Regular.ttf", i32(font_size), nil, 0)
    buffer: Buffer
    buffer.lines = make([dynamic]Line, 0, 50)

    for !rl.WindowShouldClose() {

        dt := rl.GetFrameTime()
        screen_width, screen_height := f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())
        font_width, font_height := get_font_dimentions(&font)

        buffer.offset.x = get_line_number_width(&buffer, font_width) + font_width*2

        camera_rect := rl.Rectangle{camera.target.x, camera.target.y, screen_width, screen_height}
        cursor_rect := rl.Rectangle{f32(buffer.cursor.x)*font_width, f32(buffer.cursor.y)*font_height, font_width, font_height}

        // Moving the camera.
        if !rl.CheckCollisionRecs(camera_rect, cursor_rect) {
            if camera_rect.x < cursor_rect.x do camera.target.x += font_width
            else if camera_rect.x > cursor_rect.x do camera.target.x -= font_width
            else if camera_rect.y < cursor_rect.y do camera.target.y += font_height
            else if camera_rect.y > cursor_rect.y do camera.target.y -= font_height
        }

        char := i32(rl.GetCharPressed())

        // Typing into the buffer.
        if (char >= ' ' && char <= '~') && !(rl.IsKeyDown(.LEFT_CONTROL) || rl.IsKeyDown(.LEFT_ALT)) {
            using buffer
            if len(lines) == 0 do append(&lines, Line{make([dynamic]u8)})
            if is_selection_active(&buffer) {
                delete_selection(&buffer)
            }
            inject_at(&lines[cursor.y].text, cursor.x, u8(char))
            cursor.x += 1
            reset_selection(&buffer)
        }

        // Updating the time the movement keys have been held.
        for key in timers {
            timer_update(key, dt)
        }

        key := rl.GetKeyPressed()

        if (rl.IsKeyPressed(.E) && rl.IsKeyDown(.LEFT_CONTROL))  || key == .END {
            home_toggle = true
            move_cursor_end(&buffer)
            if !rl.IsKeyDown(.LEFT_SHIFT) do reset_selection(&buffer)
        }
        if (rl.IsKeyPressed(.A) && rl.IsKeyDown(.LEFT_CONTROL)) || key == .HOME {
            if home_toggle do move_cursor_home(&buffer)
            else do move_cursor_home_non_whitespace(&buffer)
            home_toggle = !home_toggle
            if !rl.IsKeyDown(.LEFT_SHIFT) do reset_selection(&buffer)
        }

        if key_is_pressed_or_down(key, .BACKSPACE) {
            if is_selection_active(&buffer) do delete_selection(&buffer)
            else do press_backspace(&buffer)
            reset_selection(&buffer)
        }

        if key_is_pressed_or_down(key, .ENTER) {
            if is_selection_active(&buffer) do delete_selection(&buffer)
            press_enter(&buffer)
            reset_selection(&buffer)
        }
        
        if key_is_pressed_or_down(key, .UP) {
            move_cursor_up(&buffer)
            if !rl.IsKeyDown(.LEFT_SHIFT) do reset_selection(&buffer)
        }

        if key_is_pressed_or_down(key, .DOWN) {
            move_cursor_down(&buffer)
            if !rl.IsKeyDown(.LEFT_SHIFT) do reset_selection(&buffer)
        }

        if key_is_pressed_or_down(key, .LEFT) {
            move_cursor_left(&buffer)
            if !rl.IsKeyDown(.LEFT_SHIFT) do reset_selection(&buffer)
        }

        if key_is_pressed_or_down(key, .RIGHT) {
            move_cursor_right(&buffer)
            if !rl.IsKeyDown(.LEFT_SHIFT) do reset_selection(&buffer)
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

        rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)
        rl.BeginMode2D(camera)
        {
            using buffer

            when DEBUG do fmt.println("---------------------")

            start, end: [2]int
            if is_selection_active(&buffer) do start, end = get_selection_boundaries(&buffer)
            draw_cursor(cursor, offset, font_width, font_height)

            for _, i in lines {
                draw_line_number(&buffer, i, font_width, font_height, font)

                if is_selection_active(&buffer) {
                    draw_line_selection(&buffer, i, start, end, font_width, font_height)
                }

                when DEBUG do fmt.println(i+1, ":", transmute(string)lines[i].text[:])
                draw_line_text(&buffer, i, font_size, font)
            }
            free_all(context.temp_allocator)
            when DEBUG do fmt.println("---------------------")

        }
        rl.EndMode2D()

        when DEBUG {
            if len(lines) > 0 {
                rl.DrawText(rl.TextFormat("line width: %i", i32(len(lines[cursor.y].text))), 400, 0, 30, rl.WHITE)
            }
            rl.DrawText(rl.TextFormat("line count: %i", i32(len(lines))), 400, 30, 30, rl.WHITE)
            rl.DrawText(rl.TextFormat("cursor: %i, %i", i32(cursor.x), i32(cursor.y)), 400, 60, 30, rl.WHITE)
            rl.DrawText(rl.TextFormat("select: %i, %i", i32(select.x), i32(select.y)), 400, 90, 30, rl.WHITE)
        }
        rl.EndDrawing()
    }
}
