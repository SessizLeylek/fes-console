package console

import "core:terminal"
import "core:strings"

CODELINE_SIZE :: 64
TERMINAL_WIDTH :: SCREEN_WIDTH / CHARSIZE
TERMINAL_HEIGHT :: SCREEN_HEIGHT / CHARSIZE

TerminalEntry :: struct
{
    is_initted : bool,
    cursor : [2]int,
    last_cursor_blink : f64,
}

TerminalCodeEditor :: struct
{
    is_initted : bool,
    cursor : [2]int,
    top_left_position : [2]int,
    last_cursor_blink : f64,
}

TerminalMemoryEditor :: struct
{

}

TerminalData :: struct
{
    should_refresh : bool,
    color : u8,
    chars : [TERMINAL_HEIGHT][TERMINAL_WIDTH]u8,
    char_colors : [TERMINAL_HEIGHT][TERMINAL_WIDTH]u8,
    state : union {
        TerminalEntry,
        TerminalCodeEditor,
        TerminalMemoryEditor,
    },
    code : [dynamic][CODELINE_SIZE]u8,
}

INITIAL_TERMINAL_DATA := TerminalData{
    should_refresh = true,
    color = 15,
    state = TerminalEntry {},
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
            terminal_draw_cell(i, j, terminal_data.chars[j][i], terminal_data.char_colors[j][i])
        }
    }
}

terminal_reset_cell_color :: proc(x, y : int)
{
    terminal_data.char_colors[y][x] = terminal_data.color

    terminal_data.should_refresh = true
}

terminal_invert_cell_color :: proc(x, y : int)
{
    old_color := terminal_data.char_colors[y][x]
    new_color := (old_color >> 4) + (old_color << 4)
    terminal_data.char_colors[y][x] = new_color

    terminal_data.should_refresh = true
}

terminal_cursor_blink :: proc(v : $T)
{
    if get_time() > v.last_cursor_blink + 0.5
    {
        v.last_cursor_blink = get_time()
        terminal_invert_cell_color(v.cursor.x, v.cursor.y)
    }
}

terminal_clear_line :: proc(line_number : int)
{
    terminal_data.chars[line_number] = 0

    terminal_data.should_refresh = true
}

terminal_scroll_up :: proc()
{
    for i in 0..<TERMINAL_WIDTH
    {
        for j in 0..<(TERMINAL_HEIGHT - 1)
        {
            terminal_data.chars[j][i] = terminal_data.chars[j + 1][i]
            terminal_data.char_colors[j][i] = terminal_data.char_colors[j + 1][i]

        }
    }

    #partial switch &v in terminal_data.state
    {
        case TerminalEntry:
            if v.cursor.y > 0 do v.cursor.y -= 1
    }

    terminal_clear_line(TERMINAL_HEIGHT - 1)
}

terminal_update :: proc()
{
    
    switch &v in terminal_data.state
    {
        case TerminalEntry:
            terminal_update_entry(&v)
        case TerminalCodeEditor:
            terminal_update_code_editor(&v)
        case TerminalMemoryEditor:
    }

    if terminal_data.should_refresh
    {
    	terminal_data.should_refresh = false
    	
		terminal_draw_all()
    	update_buffer24_from_buffer4(console_get_video_buffer())    	
    }

}

terminal_print :: proc(v : ^TerminalEntry, text : string)
{
    terminal_reset_cell_color(v.cursor.x, v.cursor.y)
    terminal_clear_line(v.cursor.y)

    for i in 0..<min(len(text), TERMINAL_WIDTH)
    {
        terminal_data.chars[v.cursor.y][i] = text[i]
    }

    v.cursor.x = 0
    v.cursor.y += 1
    
    if(v.cursor.y == TERMINAL_HEIGHT) do terminal_scroll_up()

    terminal_data.should_refresh = true
}

TerminalCommand :: enum {
    None, Help, Code, MemEdit, Compile, Save, Load, Start, Color,
}

get_command :: proc(char_array : []u8) -> TerminalCommand
{
    word := strings.clone_from_bytes(char_array[:])
    first_null := strings.index_byte(word, 0)
    word_trimmed := strings.trim_space(word[:first_null])

    defer delete(word)

    if strings.equal_fold(word_trimmed, "HELP") do return .Help
    if strings.equal_fold(word_trimmed, "CODE") do return .Code
    if strings.equal_fold(word_trimmed, "MEMEDIT") do return .MemEdit
    if strings.equal_fold(word_trimmed, "COMPILE") do return .Compile
    if strings.equal_fold(word_trimmed, "SAVE") do return .Save
    if strings.equal_fold(word_trimmed, "LOAD") do return .Load
    if strings.equal_fold(word_trimmed, "START") do return .Start
    if strings.equal_fold(word_trimmed, "COLOR") do return .Color

    return .None
}

terminal_update_entry :: proc(v : ^TerminalEntry)
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
    if v.cursor.x == 0
    {
        terminal_reset_cell_color(v.cursor.x, v.cursor.y)
        terminal_data.chars[v.cursor.y][0] = '>'

        v.cursor.x = 1
    }

    // Cursor blink
    terminal_cursor_blink(v)

    // Letter typing
    if new_char := get_key_letter(); new_char != 0 && v.cursor.x < TERMINAL_WIDTH - 1
    {
        terminal_reset_cell_color(v.cursor.x, v.cursor.y)
        terminal_data.chars[v.cursor.y][v.cursor.x] = new_char

        v.cursor.x += 1
    }

    // Deleting letter
    if get_key_pressed() == .BACKSPACE
    {
        terminal_reset_cell_color(v.cursor.x, v.cursor.y)

        v.cursor.x -= 1

        if v.cursor.x == -1
        {
            v.cursor.x = 0
        }

        terminal_data.chars[v.cursor.y][v.cursor.x] = 0
    }

    // Submitting command
    if get_key_pressed() == .ENTER
    {
        terminal_reset_cell_color(v.cursor.x, v.cursor.y)

        command := get_command(terminal_data.chars[v.cursor.y][1:])
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
                terminal_data.state = TerminalCodeEditor{}
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

terminal_code_shift_buffer :: proc(x, y : int, to_right : bool)
{
    shift_value := int(to_right)
    for i in x..<(CODELINE_SIZE - shift_value)
    {
        terminal_data.code[y][i + shift_value] = terminal_data.code[y][i + (1 - shift_value)]
    }
}

terminal_code_insert :: proc(x, y : int, char : u8)
{
    terminal_code_shift_buffer(x, y, true)
    terminal_data.code[y][x] = char
}

terminal_code_remove :: proc(x, y : int)
{
    terminal_code_shift_buffer(x, y, false)
}

terminal_update_code_editor :: proc(codeEditor : ^TerminalCodeEditor)
{

    empty_line : [64]u8
    if !codeEditor.is_initted
    {
        codeEditor.is_initted = true

        terminal_data.char_colors = terminal_data.color

        if len(terminal_data.code) == 0
        {
            append(&terminal_data.code, empty_line)
        }
    }

    // Cursor blink
    terminal_cursor_blink(codeEditor)

    // Letter typing
    if new_char := get_key_letter(); new_char != 0 && codeEditor.cursor.x < 64
    {
        terminal_reset_cell_color(codeEditor.cursor.x, codeEditor.cursor.y)

        terminal_code_insert(codeEditor.cursor.x, codeEditor.cursor.y, new_char)
        codeEditor.cursor.x += 1
    }

    // Deleting letter
    if get_key_pressed() == .BACKSPACE
    {
        terminal_reset_cell_color(codeEditor.cursor.x, codeEditor.cursor.y)

        codeEditor.cursor.x -= 1

        if codeEditor.cursor.x == -1
        {
            codeEditor.cursor.x = 0
        }

        terminal_code_remove(codeEditor.cursor.x, codeEditor.cursor.y)
    }

    // New line
    if get_key_pressed() == .ENTER
    {
        inject_at(&terminal_data.code, codeEditor.cursor.y, empty_line)
        codeEditor.cursor.y += 1
    }

    // Move Cursor
    if get_key_pressed() == .RIGHT
    {
        if codeEditor.cursor.x < CODELINE_SIZE do codeEditor.cursor.x += 1
    }
    else if get_key_pressed() == .LEFT
    {
        if codeEditor.cursor.x > 0 do codeEditor.cursor.x -= 1
    }
    else if get_key_pressed() == .DOWN
    {
        if codeEditor.cursor.y < len(terminal_data.code) do codeEditor.cursor.y += 1
    }
    else if get_key_pressed() == .UP
    {
        if codeEditor.cursor.y > 0 do codeEditor.cursor.y -= 1
    }

}
