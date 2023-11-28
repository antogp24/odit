package odit 
import "core:fmt"
import "core:strings"
import rl "vendor:raylib"

Cursor :: struct {
    x, y: int
}

Line :: struct {
    number: int,
    text: [dynamic]u8
}

Buffer :: struct {
    cursor: Cursor,
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
    return strings.unsafe_string_to_cstring(transmute(string)(text[:]))
}

istypeable :: proc(c: i32) -> bool {
    return c >= ' ' && c <= '~'
}

FONT_SIZE :: 30

main :: proc() {
    rl.SetConfigFlags({.MSAA_4X_HINT, .WINDOW_RESIZABLE})
    rl.InitWindow(600, 400, "Odit")
    defer rl.CloseWindow()

    font := rl.LoadFontEx("assets/UbuntuMono-Regular.ttf", FONT_SIZE, nil, 0)
    buffer := Buffer{Cursor{0, 0}, make([dynamic]Line)}

    rl.SetTargetFPS(60)

    for !rl.WindowShouldClose() {

        pressed := i32(rl.GetCharPressed())
        if istypeable(pressed) {
            using buffer
            fmt.println(cursor.x, cap(lines))
            // inject_at()
            if len(lines) == 0 {
                append(&lines, Line{0, make([dynamic]u8)})
            }
            append(&lines[cursor.y].text, u8(pressed))
            cursor.x += 1
        }

        key := rl.GetKeyPressed()
        #partial switch(key) {
            case .BACKSPACE:
                using buffer

            case .ENTER:
                using buffer
                cursor.x = 0
                cursor.y += 1
                append(&lines, Line{cursor.y, make([dynamic]u8)})
            case .RIGHT:
                using buffer
                if cursor.x + 1 <= cap(lines[cursor.y].text) {
                    cursor.x += 1
                }
                else if cursor.y + 1 <= cap(lines) {
                    cursor.y += 1
                }
            case .LEFT:
                using buffer
                if cursor.x - 1 >= 0 {
                    cursor.x -= 1
                }
                else if cursor.y - 1 >= 0 {
                    cursor.y -= 1
                }
        }

        rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)
        {
            using buffer
            for _, i in lines {
                text := alias_as_cstring(lines[i].text)
                pos := rl.Vector2{0, f32(lines[i].number*FONT_SIZE)}
                rl.DrawTextEx(font, text, pos, FONT_SIZE, 0, rl.WHITE)
            }
            mz := rl.MeasureTextEx(font, "a", FONT_SIZE, 0)
            width, height := mz.x, mz.y
            _ = mz
            rl.DrawRectangleRec(rl.Rectangle{f32(cursor.x)*width, f32(cursor.y)*height, width, height}, rl.GREEN)
        }
        rl.EndDrawing()
    }
}
