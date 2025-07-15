package console

TERMINAL_WIDTH :: 42
TERMINAL_HEIGHT :: 32

TerminalData :: struct
{
    chars : [TERMINAL_WIDTH][TERMINAL_HEIGHT]u8,
    char_colors : [TERMINAL_WIDTH][TERMINAL_HEIGHT]u8,
}

terminal_data : TerminalData

terminal_refresh_line :: proc(line_number : u8)
{
    assert(line_number < TERMINAL_HEIGHT)

    
}
