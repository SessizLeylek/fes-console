package console

import rl "vendor:raylib"

get_time :: rl.GetTime

get_key_pressed :: proc() -> i32
{
    return i32(rl.GetKeyPressed())
}
