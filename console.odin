package console

import "core:math/rand"

CONSOLE_MEMORY :: 64*1024
ADDRESS_VIDEO_BUFFER :: 40*1024

console_memory : [CONSOLE_MEMORY]u8

console_get_video_buffer :: proc() -> []u8
{
    return console_memory[ADDRESS_VIDEO_BUFFER:]
}

console_randomize_video_buffer :: proc()
{
    for i in ADDRESS_VIDEO_BUFFER..<CONSOLE_MEMORY
    {
        console_memory[i] = u8(rand.int_max(256))
    }
}
