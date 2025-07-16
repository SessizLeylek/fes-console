package console

import rl "vendor:raylib"

get_time :: rl.GetTime

get_key_pressed :: proc() -> i32
{
    return i32(rl.GetKeyPressed())
}

get_key_letter :: proc() -> u8
{
    key_i32 := get_key_pressed()

    if key_i32 > 31 && key_i32 < 127 do return u8(key_i32)

    return 0
}
