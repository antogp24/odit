package odit 
import "core:fmt"
import "core:runtime"
import "core:strings"
import rl "vendor:raylib"

DEBUG :: false
font_size := i32(24)

Line :: struct {
    number: int,
    text: [dynamic]u8
}

CursorPos :: struct {
    x, y: int
}

Buffer :: struct {
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

pressing_down_modifiers :: proc() -> bool {
    return rl.IsKeyDown(.LEFT_SHIFT)   || rl.IsKeyDown(.RIGHT_SHIFT)   ||
           rl.IsKeyDown(.LEFT_CONTROL) || rl.IsKeyDown(.RIGHT_CONTROL) ||
           rl.IsKeyDown(.LEFT_ALT)     || rl.IsKeyDown(.RIGHT_ALT)
}

main :: proc() {
    rl.SetConfigFlags({.MSAA_4X_HINT, .WINDOW_RESIZABLE})
    rl.InitWindow(600, 400, "Odit")
    defer rl.CloseWindow()
    font := rl.LoadFontEx("assets/UbuntuMono-Regular.ttf", i32(font_size), nil, 0)
    buffer := Buffer{{0, 0}, make([dynamic]Line)}

    rl.SetTargetFPS(60)

    for !rl.WindowShouldClose() {

        key := rl.GetKeyPressed()
        pressed := i32(rl.GetCharPressed())

        if pressed >= ' ' && pressed <= '~' && !pressing_down_modifiers() {
            using buffer
            if len(lines) == 0 {
                append(&lines, Line{0, make([dynamic]u8)})
            }
            inject_at(&lines[cursor.y].text, cursor.x, u8(pressed))
            cursor.x += 1
        }

        #partial switch(key) {
            case .BACKSPACE:
                using buffer
                if cursor.x == 0  && cursor.y - 1 >= 0 {
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

            case .ENTER:
                using buffer
                
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
            
            case .UP:
                using buffer
                if cursor.y - 1 >= 0 {
                    cursor.y -= 1
                    if cursor.x > len(lines[cursor.y].text) {
                        cursor.x = len(lines[cursor.y].text)
                    }
                }

            case .DOWN:
                using buffer
                if cursor.y + 1 < len(lines) {
                    cursor.y += 1
                    if cursor.x > len(lines[cursor.y].text) {
                        cursor.x = len(lines[cursor.y].text)
                    }
                }

            case .RIGHT:
                using buffer
                if cursor.x + 1 <= len(lines[cursor.y].text) {
                    cursor.x += 1
                }
                else if cursor.y + 1 < len(lines) {
                    cursor.x = 0
                    cursor.y += 1
                }

            case .LEFT:
                using buffer
                if cursor.x - 1 >= 0 {
                    cursor.x -= 1
                }
                else if cursor.y - 1 >= 0 {
                    cursor.y -= 1
                    cursor.x = len(lines[cursor.y].text)
                }
        }

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
        {
            using buffer

            // Cursor
            width, height := get_font_dimentions(&font)
            rl.DrawRectangleRec(rl.Rectangle{f32(cursor.x)*width, f32(cursor.y)*height, width, height}, rl.GREEN)

            // Buffer text
            when DEBUG do fmt.println("---------------------")
            for _, i in lines {
                when DEBUG do fmt.println(lines[i].number, ":", transmute(string)lines[i].text[:])
                text := copy_to_cstring(lines[i].text)
                pos := rl.Vector2{0, f32(lines[i].number*cast(int)font_size)}
                rl.DrawTextEx(font, text, pos, f32(font_size), 0, rl.WHITE)
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
