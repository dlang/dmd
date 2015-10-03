/***********************************************************************\
*                               lmuseflg.d                              *
*                                                                       *
*                       Windows API header module                       *
*                                                                       *
*             Translated from MinGW API for MS-Windows 3.10             *
*                                                                       *
*                       Placed into public domain                       *
\***********************************************************************/
module core.sys.windows.lmuseflg;

enum : uint {
	USE_NOFORCE = 0,
	USE_FORCE,
	USE_LOTS_OF_FORCE // = 2
}
