package console

import "core:strings"

TERMINAL_WIDTH :: SCREEN_WIDTH / CHARSIZE
TERMINAL_HEIGHT :: SCREEN_HEIGHT / CHARSIZE

TerminalEntry :: struct
{
    is_initted : bool,
    cursor_x, cursor_y : int,
    line_text : [TERMINAL_WIDTH]u8,
    last_cursor_blink : f64,
}

TerminalCodeEditor :: struct
{

}

TerminalMemoryEditor :: struct
{

}

TerminalData :: struct
{
    color : u8,
    chars : [TERMINAL_WIDTH][TERMINAL_HEIGHT]u8,
    char_colors : [TERMINAL_WIDTH][TERMINAL_HEIGHT]u8,
    state : union {
        TerminalEntry,
        TerminalCodeEditor,
        TerminalMemoryEditor,
    }
}

terminal_data : TerminalData

terminal_draw_cell :: proc(x, y : int, char, color : u8)
{
    color_bg := color >> 4
    color_fg := (color << 4) >> 4

    real_x := x * CHARSIZE
    real_y := y * CHARSIZE

    char_info := charset_get_char_info(char)

    for row in 0..<CHARSIZE
    {
        for col in 0..<CHARSIZE
        {
            pixel_color := char_info[row][col] ? color_bg : color_fg
            console_draw_single_pixel(real_x + col, real_y + row, pixel_color)
        }
    }
}

terminal_draw_all :: proc()
{
    for i in 0..<TERMINAL_WIDTH
    {
        for j in 0..<TERMINAL_HEIGHT
        {
            terminal_draw_cell(i, j, terminal_data.chars[i][j], terminal_data.char_colors[i][j])
        }
    }
}

terminal_reset_cell_color :: proc(x, y : int)
{
    terminal_data.char_colors[x][y] = terminal_data.color
}

terminal_invert_cell_color :: proc(x, y : int)
{
    old_color := terminal_data.char_colors[x][y]
    new_color := (old_color >> 4) + (old_color << 4)
    terminal_data.char_colors[x][y] = new_color
}

terminal_clear_line :: proc(line_number : int)
{
    for i in 0..<TERMINAL_WIDTH
    {
        terminal_data.chars[i][line_number] = 0
    }
}

terminal_scroll_up :: proc()
{
    for i in 0..<TERMINAL_WIDTH
    {
        for j in 0..<(TERMINAL_HEIGHT - 1)
        {
            terminal_data.chars[i][j] = terminal_data.chars[i][j + 1]
            terminal_data.char_colors[i][j] = terminal_data.char_colors[i][j + 1]

        }
    }

    #partial switch &v in terminal_data.state
    {
        case TerminalEntry:
            if v.cursor_y > 0 do v.cursor_y -= 1
    }

    terminal_clear_line(TERMINAL_HEIGHT - 1)
}

terminal_update :: proc(time : f64, pressed_key : i32)
{
    
    switch &v in terminal_data.state
    {
        case TerminalEntry:
            terminal_update_entry(time, pressed_key, &v)
        case TerminalCodeEditor:
        case TerminalMemoryEditor:
    }

    terminal_draw_all()
    update_buffer24_from_buffer4(console_get_video_buffer())
}

terminal_print :: proc(v : ^TerminalEntry, text : string)
{
    terminal_reset_cell_color(v.cursor_x, v.cursor_y)
    terminal_clear_line(v.cursor_y)

    for i in 0..<min(len(text), TERMINAL_WIDTH)
    {
        terminal_data.chars[i][v.cursor_y] = text[i]
    }

    v.cursor_x = 0
    v.cursor_y += 1
    v.line_text = 0
    
    if(v.cursor_y == TERMINAL_HEIGHT) do terminal_scroll_up()
}

TerminalCommand :: enum {
    None, Help, Code, MemEdit, Compile, Save, Load, Start, Color,
}

get_command :: proc(char_array : []u8) -> TerminalCommand
{
    word := strings.clone_from_bytes(char_array[:])
    first_null := strings.index_byte(word, 0)
    word_trimmed := strings.trim_space(word[:first_null])

    printfln("%v %v", word_trimmed, len(word_trimmed))

    defer delete(word)

    if strings.compare(word_trimmed, "HELP") == 0 do return .Help
    if strings.compare(word_trimmed, "CODE") == 0 do return .Code
    if strings.compare(word_trimmed, "MEMEDIT") == 0 do return .MemEdit
    if strings.compare(word_trimmed, "COMPILE") == 0 do return .Compile
    if strings.compare(word_trimmed, "SAVE") == 0 do return .Save
    if strings.compare(word_trimmed, "LOAD") == 0 do return .Load
    if strings.compare(word_trimmed, "START") == 0 do return .Start
    if strings.compare(word_trimmed, "COLOR") == 0 do return .Color

    return .None
}

terminal_update_entry :: proc(time : f64, pressed_key : i32, v : ^TerminalEntry)
{
    if !v.is_initted
    {
        v.is_initted = true

        terminal_data.char_colors = terminal_data.color

        terminal_print(v, "WELCOME TO THE FES TERMINAL!")
        terminal_print(v, "TYPE \"HELP\" TO GET HELP")
        terminal_print(v, " ")
    }

    // Put command symbol
    if v.cursor_x == 0
    {
        terminal_reset_cell_color(v.cursor_x, v.cursor_y)
        terminal_data.chars[v.cursor_x][v.cursor_y] = '>'

        v.line_text[v.cursor_x] = '>'
        v.cursor_x = 1
    }

    // Cursor blink
    if time > v.last_cursor_blink + 0.5
    {
        v.last_cursor_blink = time
        terminal_invert_cell_color(v.cursor_x, v.cursor_y)
    }

    // Letter typing
    if pressed_key > 31 && pressed_key < 127 && v.cursor_x < TERMINAL_WIDTH - 1
    {
        new_char := u8(pressed_key)

        terminal_reset_cell_color(v.cursor_x, v.cursor_y)
        terminal_data.chars[v.cursor_x][v.cursor_y] = new_char

        v.line_text[v.cursor_x] = new_char
        v.cursor_x += 1

    }

    // Deleting letter
    BACKSPACE :: 259
    if pressed_key == BACKSPACE
    {
        terminal_reset_cell_color(v.cursor_x, v.cursor_y)

        v.cursor_x -= 1

        if v.cursor_x == -1
        {
            v.cursor_x = 0
        }

        v.line_text[v.cursor_x] = 0
        terminal_data.chars[v.cursor_x][v.cursor_y] = 0
    }

    // Submitting command
    ENTER :: 257
    if pressed_key == ENTER
    {
        terminal_reset_cell_color(v.cursor_x, v.cursor_y)

        command := get_command(v.line_text[1:])
        switch command
        {
            case .Help:
                terminal_print(v, "FES TERMINAL HELP UTILITY")
                terminal_print(v, "    HELP: SHOWS THIS DIALOG")
                terminal_print(v, "    CODE: OPENS THE CODE EDITOR")
                terminal_print(v, "    MEMEDIT: OPENS THE MEMORY EDITOR")
                terminal_print(v, "    COMPILE: COMPILES CODE TO MEMORY")
                terminal_print(v, "    SAVE: SAVES THE GAME TO CARTRIDGE")
                terminal_print(v, "    LOAD: LOADS A GAME FROM THE CARTRIDGE")
                terminal_print(v, "    START: STARTS THE GAME")
                terminal_print(v, "    COLOR: CHANGES TERMINAL COLOR")
                terminal_print(v, "")
            case .Code:
            case .MemEdit:
            case .Compile:
            case .Save:
            case .Load:
            case .Start:
            case .Color:
                terminal_data.color += 1
                if terminal_data.color == 16 do terminal_data.color = 1
                terminal_data.char_colors = terminal_data.color
            case .None:
                terminal_print(v, "INVALID COMMAND!")
                terminal_print(v, "")
        }        
    }
}

