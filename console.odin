package console

import "core:math/rand"

CONSOLE_MEMORY :: 64*1024
ADDRESS_VIDEO_BUFFER :: 40*1024

console_memory : [CONSOLE_MEMORY]u8

console_get_video_buffer :: proc() -> []u8
{
    return console_memory[ADDRESS_VIDEO_BUFFER:]
}

console_draw_single_pixel :: proc(x, y : int, color : u8)
{
    pixel_offset := (x + y * SCREEN_WIDTH) / 2
    old_byte := console_memory[ADDRESS_VIDEO_BUFFER + pixel_offset]

    if x % 2 == 0
    {
        // First pixel of two
        old_byte = old_byte & 0b00001111
        console_memory[ADDRESS_VIDEO_BUFFER + pixel_offset] = old_byte + (color << 4)
    }
    else
    {
        // Second pixel of two
        old_byte = old_byte & 0b11110000
        console_memory[ADDRESS_VIDEO_BUFFER + pixel_offset] = old_byte + color
    }
}

console_randomize_video_buffer :: proc()
{
    for i in ADDRESS_VIDEO_BUFFER..<CONSOLE_MEMORY
    {
        console_memory[i] = u8(rand.int_max(256))
    }
}
