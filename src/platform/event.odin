package omeplatform

import SDL "vendor:sdl3"

Key :: enum {
	// USB HID usage codes
	// --- page0x07
	Unknown                 = 0,
	A                       = 4,
	B                       = 5,
	C                       = 6,
	D                       = 7,
	E                       = 8,
	F                       = 9,
	G                       = 10,
	H                       = 11,
	I                       = 12,
	J                       = 13,
	K                       = 14,
	L                       = 15,
	M                       = 16,
	N                       = 17,
	O                       = 18,
	P                       = 19,
	Q                       = 20,
	R                       = 21,
	S                       = 22,
	T                       = 23,
	U                       = 24,
	V                       = 25,
	W                       = 26,
	X                       = 27,
	Y                       = 28,
	Z                       = 29,
	One                     = 30,
	Two                     = 31,
	Three                   = 32,
	Four                    = 33,
	Five                    = 34,
	Six                     = 35,
	Seven                   = 36,
	Eight                   = 37,
	Nine                    = 38,
	Zero                    = 39,
	Return                  = 40,
	Escape                  = 41,
	Backspace               = 42,
	Tab                     = 43,
	Space                   = 44,
	Minus                   = 45,
	Equals                  = 46,
	Left_Bracket            = 47,
	Right_Bracket           = 48,
	Backslash               = 49,
	Non_US_Hash             = 50,
	Semicolon               = 51,
	Apostrophe              = 52,
	Grave                   = 53,
	Comma                   = 54,
	Period                  = 55,
	Slash                   = 56,
	Capslock                = 57,
	F1                      = 58,
	F2                      = 59,
	F3                      = 60,
	F4                      = 61,
	F5                      = 62,
	F6                      = 63,
	F7                      = 64,
	F8                      = 65,
	F9                      = 66,
	F10                     = 67,
	F11                     = 68,
	F12                     = 69,
	Printscreen             = 70,
	Scrolllock              = 71,
	Pause                   = 72,
	Insert                  = 73,
	Home                    = 74,
	Pageup                  = 75,
	Delete                  = 76,
	End                     = 77,
	Pagedown                = 78,
	Right                   = 79,
	Left                    = 80,
	Down                    = 81,
	Up                      = 82,
	Numlock_Clear           = 83,
	Numpad_Divide           = 84,
	Numpad_Multiply         = 85,
	Numpad_Minus            = 86,
	Numpad_Plus             = 87,
	Numpad_Enter            = 88,
	Numpad_One              = 89,
	Numpad_Two              = 90,
	Numpad_Three            = 91,
	Numpad_Four             = 92,
	Numpad_Five             = 93,
	Numpad_Six              = 94,
	Numpad_Seven            = 95,
	Numpad_Eight            = 96,
	Numpad_Nine             = 97,
	Numpad_Zero             = 98,
	Numpad_Period           = 99,
	Non_US_Backslash        = 100,
	Application             = 101,
	Power                   = 102,
	Numpad_Equals           = 103,
	F13                     = 104,
	F14                     = 105,
	F15                     = 106,
	F16                     = 107,
	F17                     = 108,
	F18                     = 109,
	F19                     = 110,
	F20                     = 111,
	F21                     = 112,
	F22                     = 113,
	F23                     = 114,
	F24                     = 115,
	Execute                 = 116,
	Help                    = 117,
	Menu                    = 118,
	Select                  = 119,
	Stop                    = 120,
	Again                   = 121,
	Undo                    = 122,
	Cut                     = 123,
	Copy                    = 124,
	Paste                   = 125,
	Find                    = 126,
	Mute                    = 127,
	Volume_Up               = 128,
	Volume_Down             = 129,
	// Locking_Capslock     = 130,
	// Locking_Numlock      = 131,
	// Locking_Scrolllock   = 132,
	Numpad_Comma            = 133,
	Numpad_Equals_As_400    = 134,
	International_One       = 135,
	International_Two       = 136,
	International_Three     = 137,
	International_Four      = 138,
	International_Five      = 139,
	International_Six       = 140,
	International_Seven     = 141,
	International_Eight     = 142,
	International_Nine      = 143,
	Lang_One                = 144,
	Lang_Two                = 145,
	Lang_Three              = 146,
	Lang_Four               = 147,
	Lang_Five               = 148,
	Lang_Six                = 149,
	Lang_Seven              = 150,
	Lang_Eight              = 151,
	Lang_Nine               = 152,
	Alterase                = 153,
	Sysreq                  = 154,
	Cancel                  = 155,
	Clear                   = 156,
	Prior                   = 157,
	Return_Two              = 158,
	Separator               = 159,
	Out                     = 160,
	Oper                    = 161,
	Clearagain              = 162,
	Crsel                   = 163,
	Exsel                   = 164,
	Kp_00                   = 176,
	Kp_000                  = 177,
	Thousands_Separator     = 178,
	Decimal_Separator       = 179,
	Currency_Unit           = 180,
	Currencys_UB_unit       = 181,
	Numpad_Leftparen        = 182,
	Numpad_Right_Paren      = 183,
	Numpad_Left_Brace       = 184,
	Numpad_Right_Brace      = 185,
	Numpad_Tab              = 186,
	Numpad_Backspace        = 187,
	Numpad_A                = 188,
	Numpad_B                = 189,
	Numpad_C                = 190,
	Numpad_D                = 191,
	Numpad_R                = 192,
	Numpad_F                = 193,
	Numpad_Xor              = 194,
	Numpad_Power            = 195,
	Numpad_Percent          = 196,
	Numpad_Less             = 197,
	Numpad_Greater          = 198,
	Numpad_Ampersand        = 199,
	Numpad_Dblampersand     = 200,
	Numpad_Vertical_Bar     = 201,
	Numpad_DBL_Vertical_Bar = 202,
	Numpad_Colon            = 203,
	Numpad_Hash             = 204,
	Numpad_Space            = 205,
	Numpad_At               = 206,
	Numpad_Exclam           = 207,
	Numpad_Mem_Store        = 208,
	Numpad_Mem_Recall       = 209,
	Numpad_Mem_Clear        = 210,
	Numpad_Mem_Add          = 211,
	Numpad_Mem_Subtract     = 212,
	Numpad_Mem_Multiply     = 213,
	Numpad_Mem_Divide       = 214,
	Numpad_Plusminus        = 215,
	Numpad_Clear            = 216,
	Numpad_Clearentry       = 217,
	Numpad_Binary           = 218,
	Numpad_Octal            = 219,
	Numpad_Decimal          = 220,
	Numpad_Hexadecimal      = 221,
	Left_Control            = 224,
	Left_Shift              = 225,
	Left_Alt                = 226,
	Left_GUI                = 227,
	Right_Control           = 228,
	Right_Shift             = 229,
	Right_Alt               = 230,
	Right_GUI               = 231,
	Mode                    = 257,
	// _page0x0C
	Sleep                   = 258,
	Wake                    = 259,
	Channel_Increment       = 260,
	Channel_Decrement       = 261,
	Media_Play              = 262,
	Media_Pause             = 263,
	Media_Record            = 264,
	Media_Fast_Forward      = 265,
	Media_Rewind            = 266,
	Media_Next_Track        = 267,
	Media_Previous_Track    = 268,
	Media_Stop              = 269,
	Media_Eject             = 270,
	Media_Play_Pause        = 271,
	Media_Select            = 272,
	App_Control_New         = 273,
	App_Control_Open        = 274,
	App_Control_Close       = 275,
	App_Control_Exit        = 276,
	App_Control_Save        = 277,
	App_Control_Print       = 278,
	App_Control_Properties  = 279,
	App_Control_Search      = 280,
	App_Control_Home        = 281,
	App_Control_Back        = 282,
	App_Control_Forward     = 283,
	App_Control_Stop        = 284,
	App_Control_Refresh     = 285,
	App_Control_Bookmarks   = 286,
	Count                   = 512,
}

MouseButton :: enum u8 {
	Unknown = 0,
	Left    = 1,
	Middle  = 2,
	Right   = 3,
	X1      = 4,
	X2      = 5,
}

Event :: union {
	QuitEvent,
	ResizeEvent,
	KeyEvent,
	MouseMoveEvent,
	MouseButtonEvent,
	MouseWheelEvent,
	DropFileEvent,
}

QuitEvent :: struct {}

ResizeEvent :: struct {
	info: WindowInfo,
}

KeyEvent :: struct {
	key:  Key,
	down: bool,
}

MouseMoveEvent :: struct {
	position: [2]f32,
	delta:    [2]f32,
}

MouseButtonEvent :: struct {
	button:   MouseButton,
	down:     bool,
	position: [2]f32,
	clicks:   u8,
}

MouseWheelEvent :: struct {
	position: [2]f32,
	delta:    [2]f32,
}

DropFileEvent :: struct {
	path: string,
}

event_is_mouse :: proc(event: Event) -> bool {
	#partial switch e in event {
	case MouseMoveEvent, MouseButtonEvent, MouseWheelEvent:
		_ = e
		return true
	}
	return false
}

event_poll :: proc(window: ^Window) -> (Event, bool) {
	for e: SDL.Event; SDL.PollEvent(&e); {
		#partial switch e.type {
		case .QUIT:
			return QuitEvent{}, true
		case .WINDOW_PIXEL_SIZE_CHANGED:
			window_refresh_info(window)
			return ResizeEvent{info = window.info}, true
		case .DROP_FILE:
			return DropFileEvent{path = string(e.drop.data)}, true
		case .KEY_DOWN:
			return KeyEvent{key = Key(e.key.scancode), down = true}, true
		case .KEY_UP:
			return KeyEvent{key = Key(e.key.scancode), down = false}, true
		case .MOUSE_MOTION:
			return MouseMoveEvent {
					position = {e.motion.x, e.motion.y},
					delta = {e.motion.xrel, e.motion.yrel},
				},
				true
		case .MOUSE_BUTTON_DOWN, .MOUSE_BUTTON_UP:
			button := MouseButton.Unknown
			if e.button.button >= 1 && e.button.button <= 5 {
				button = MouseButton(e.button.button)
			}
			return MouseButtonEvent {
					button = button,
					down = e.button.down,
					position = {e.button.x, e.button.y},
					clicks = e.button.clicks,
				},
				true
		case .MOUSE_WHEEL:
			return MouseWheelEvent {
					delta = {e.wheel.x, e.wheel.y},
					position = {e.wheel.mouse_x, e.wheel.mouse_y},
				},
				true
		}
	}

	return nil, false
}
