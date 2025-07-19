package console

import "core:strings"

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
    
    if(v.cursor.y == TERMINAL_HEIGHT) 
    {
        terminal_scroll_up()
    }

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
    if get_time() > v.last_cursor_blink + CURSOR_BLINK_INTERVAL
    {
        v.last_cursor_blink = get_time()
        terminal_invert_cell_color(v.cursor.x, v.cursor.y)
    }

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
                if terminal_data.color == 16 
                {
                    terminal_data.color = 1
                }
                terminal_data.char_colors = terminal_data.color
            case .None:
                terminal_print(v, "INVALID COMMAND!")
                terminal_print(v, "")
        }        
    }
}
