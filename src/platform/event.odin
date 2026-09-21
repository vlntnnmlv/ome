package omeplatform

import "core:c"

import SDL "vendor:sdl3"

Key :: enum {
	// USB HID usage codes
	// --- page0x07
	Unknown              = 0,
	A                    = 4,
	B                    = 5,
	C                    = 6,
	D                    = 7,
	E                    = 8,
	F                    = 9,
	G                    = 10,
	H                    = 11,
	I                    = 12,
	J                    = 13,
	K                    = 14,
	L                    = 15,
	M                    = 16,
	N                    = 17,
	O                    = 18,
	P                    = 19,
	Q                    = 20,
	R                    = 21,
	S                    = 22,
	T                    = 23,
	U                    = 24,
	V                    = 25,
	W                    = 26,
	X                    = 27,
	Y                    = 28,
	Z                    = 29,
	One                  = 30,
	Two                  = 31,
	Three                = 32,
	Four                 = 33,
	Five                 = 34,
	Six                  = 35,
	Seven                = 36,
	Eight                = 37,
	Nine                 = 38,
	Zero                 = 39,
	Return               = 40,
	Escape               = 41,
	Backspace            = 42,
	Tab                  = 43,
	Space                = 44,
	Minus                = 45,
	Equals               = 46,
	Leftbracket          = 47,
	Rightbracket         = 48,
	Backslash            = 49,
	Nonushash            = 50,
	Semicolon            = 51,
	Apostrophe           = 52,
	Grave                = 53,
	Comma                = 54,
	Period               = 55,
	Slash                = 56,
	Capslock             = 57,
	F1                   = 58,
	F2                   = 59,
	F3                   = 60,
	F4                   = 61,
	F5                   = 62,
	F6                   = 63,
	F7                   = 64,
	F8                   = 65,
	F9                   = 66,
	F10                  = 67,
	F11                  = 68,
	F12                  = 69,
	Printscreen          = 70,
	Scrolllock           = 71,
	Pause                = 72,
	Insert               = 73,
	Home                 = 74,
	Pageup               = 75,
	Delete               = 76,
	End                  = 77,
	Pagedown             = 78,
	Right                = 79,
	Left                 = 80,
	Down                 = 81,
	Up                   = 82,
	Numlockclear         = 83,
	NumpadDivide         = 84,
	NumpadMultiply       = 85,
	NumpadMinus          = 86,
	NumpadPlus           = 87,
	NumpadEnter          = 88,
	NumpadOne            = 89,
	NumpadTwo            = 90,
	NumpadThree          = 91,
	NumpadFour           = 92,
	NumpadFive           = 93,
	NumpadSix            = 94,
	NumpadSeven          = 95,
	NumpadEight          = 96,
	NumpadNine           = 97,
	NumpadZero           = 98,
	NumpadPeriod         = 99,
	Nonusbackslash       = 100,
	Application          = 101,
	Power                = 102,
	NumpadEquals         = 103,
	F13                  = 104,
	F14                  = 105,
	F15                  = 106,
	F16                  = 107,
	F17                  = 108,
	F18                  = 109,
	F19                  = 110,
	F20                  = 111,
	F21                  = 112,
	F22                  = 113,
	F23                  = 114,
	F24                  = 115,
	Execute              = 116,
	Help                 = 117,
	Menu                 = 118,
	Select               = 119,
	Stop                 = 120,
	Again                = 121,
	Undo                 = 122,
	Cut                  = 123,
	Copy                 = 124,
	Paste                = 125,
	Find                 = 126,
	Mute                 = 127,
	VolumeUp             = 128,
	VolumeDown           = 129,
	// Lockingcapslock      = 130,
	// Lockingnumlock       = 131,
	// Lockingscrolllock    = 132,
	NumpadComma          = 133,
	NumpadEqualsAs400    = 134,
	InternationalOne     = 135,
	InternationalTwo     = 136,
	InternationalThree   = 137,
	InternationalFour    = 138,
	InternationalFive    = 139,
	InternationalSix     = 140,
	InternationalSeven   = 141,
	InternationalEight   = 142,
	InternationalNine    = 143,
	LangOne              = 144,
	LangTwo              = 145,
	LangThree            = 146,
	LangFour             = 147,
	LangFive             = 148,
	LangSix              = 149,
	LangSeven            = 150,
	LangEight            = 151,
	LangNine             = 152,
	Alterase             = 153,
	Sysreq               = 154,
	Cancel               = 155,
	Clear                = 156,
	Prior                = 157,
	ReturnTwo            = 158,
	Separator            = 159,
	Out                  = 160,
	Oper                 = 161,
	Clearagain           = 162,
	Crsel                = 163,
	Exsel                = 164,
	Kp00                 = 176,
	Kp000                = 177,
	Thousandsseparator   = 178,
	Decimalseparator     = 179,
	Currencyunit         = 180,
	Currencysubunit      = 181,
	NumpadLeftparen      = 182,
	NumpadRightparen     = 183,
	NumpadLeftbrace      = 184,
	NumpadRightbrace     = 185,
	NumpadTab            = 186,
	NumpadBackspace      = 187,
	NumpadA              = 188,
	NumpadB              = 189,
	NumpadC              = 190,
	NumpadD              = 191,
	NumpadE              = 192,
	NumpadF              = 193,
	NumpadXor            = 194,
	NumpadPower          = 195,
	NumpadPercent        = 196,
	NumpadLess           = 197,
	NumpadGreater        = 198,
	NumpadAmpersand      = 199,
	NumpadDblampersand   = 200,
	NumpadVerticalbar    = 201,
	NumpadDblverticalbar = 202,
	NumpadColon          = 203,
	NumpadHash           = 204,
	NumpadSpace          = 205,
	NumpadAt             = 206,
	NumpadExclam         = 207,
	NumpadMemstore       = 208,
	NumpadMemrecall      = 209,
	NumpadMemclear       = 210,
	NumpadMemadd         = 211,
	NumpadMemsubtract    = 212,
	NumpadMemmultiply    = 213,
	NumpadMemdivide      = 214,
	NumpadPlusminus      = 215,
	NumpadClear          = 216,
	NumpadClearentry     = 217,
	NumpadBinary         = 218,
	NumpadOctal          = 219,
	NumpadDecimal        = 220,
	NumpadHexadecimal    = 221,
	LeftControl          = 224,
	LeftShift            = 225,
	LeftAlt              = 226,
	LeftGUI              = 227,
	RightControl         = 228,
	RightShift           = 229,
	RightAlt             = 230,
	RightGUI             = 231,
	Mode                 = 257,
	// --- page0x0C
	Sleep                = 258,
	Wake                 = 259,
	ChannelIncrement     = 260,
	ChannelDecrement     = 261,
	MediaPlay            = 262,
	MediaPause           = 263,
	MediaRecord          = 264,
	MediaFastForward     = 265,
	MediaRewind          = 266,
	MediaNextTrack       = 267,
	MediaPreviousTrack   = 268,
	MediaStop            = 269,
	MediaEject           = 270,
	MediaPlayPause       = 271,
	MediaSelect          = 272,
	AppControlNew        = 273,
	AppControlOpen       = 274,
	AppControlClose      = 275,
	AppControlExit       = 276,
	AppControlSave       = 277,
	AppControlPrint      = 278,
	AppControlProperties = 279,
	AppControlSearch     = 280,
	AppControlHome       = 281,
	AppControlBack       = 282,
	AppControlForward    = 283,
	AppControlStop       = 284,
	AppControlRefresh    = 285,
	AppControlBookmarks  = 286,
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

poll_event :: proc(window: ^Window) -> (Event, bool) {
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

key_down :: proc(key: Key) -> bool {
	numkeys: c.int
	state := SDL.GetKeyboardState(&numkeys)
	if state == nil do return false
	if int(key) < 0 || int(key) >= int(numkeys) do return false
	return state[int(key)]
}

mouse_position :: proc() -> [2]f32 {
	x, y: f32
	flags := SDL.GetMouseState(&x, &y)
	_ = flags
	return {x, y}
}

mouse_button_down :: proc(button: MouseButton) -> bool {
	flags := SDL.GetMouseState(nil, nil)
	#partial switch button {
	case .Left:
		return .LEFT in flags
	case .Middle:
		return .MIDDLE in flags
	case .Right:
		return .RIGHT in flags
	case .X1:
		return .X1 in flags
	case .X2:
		return .X2 in flags
	}
	return false
}
