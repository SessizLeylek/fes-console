package console

import rl "vendor:raylib"

get_time :: rl.GetTime

KeyboardState :: struct{
    is_ctrl_pressed : bool,
    key : rl.KeyboardKey,
    char : rune,
}

keyboard_state : KeyboardState

update_keyboard_state :: proc()
{
    using keyboard_state 

    char = rl.GetCharPressed()
    key = rl.GetKeyPressed()
    is_ctrl_pressed = rl.IsKeyDown(.LEFT_CONTROL) || rl.IsKeyDown(.RIGHT_CONTROL)
}

get_key_letter :: proc() -> u8
{
    char := keyboard_state.char
    if char >= ' ' && char <= '~' do return u8(char)

    return 0
}

save_file :: rl.SaveFileData
load_file :: rl.LoadFileData
