/***********************************************************************\
*                                cplext.d                               *
*                                                                       *
*                       Windows API header module                       *
*                                                                       *
*             Translated from MinGW API for MS-Windows 3.10             *
*                           by Stewart Gordon                           *
*                                                                       *
*                       Placed into public domain                       *
\***********************************************************************/
module win32.cplext;

enum : uint {
	CPLPAGE_MOUSE_BUTTONS      = 1,
	CPLPAGE_MOUSE_PTRMOTION    = 2,
	CPLPAGE_MOUSE_WHEEL        = 3,
	CPLPAGE_KEYBOARD_SPEED     = 1,
	CPLPAGE_DISPLAY_BACKGROUND = 1
}
