package console

import rl "vendor:raylib"

get_time :: rl.GetTime

KeyboardState :: struct{
    last_pressed_key : rl.KeyboardKey,
    last_pressed_char : rune,
    last_check_time : f64,
}

_keyboard_state : KeyboardState

get_keyboard_state :: proc()
{
    if abs(get_time() - _keyboard_state.last_check_time) < 0.01 do return

    _keyboard_state.last_check_time = get_time()
    _keyboard_state.last_pressed_char = rl.GetCharPressed()
    _keyboard_state.last_pressed_key = rl.GetKeyPressed()
}

get_key_pressed :: proc() -> rl.KeyboardKey
{
    get_keyboard_state()
    return _keyboard_state.last_pressed_key
}

get_key_letter :: proc() -> u8
{
    get_keyboard_state()

    char := _keyboard_state.last_pressed_char
    if char >= ' ' && char <= '~' do return u8(char)

    return 0
}

save_file :: rl.SaveFileData
load_file :: rl.LoadFileData
