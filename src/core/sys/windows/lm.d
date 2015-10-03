/***********************************************************************\
*                                  lm.d                                 *
*                                                                       *
*                       Windows API header module                       *
*                                                                       *
*                 Translated from MinGW Windows headers                 *
*                                                                       *
*                       Placed into public domain                       *
\***********************************************************************/
module win32.lm;
/* removed - now supporting only Win2k up
version (WindowsVista) {
	version = WIN32_WINNT_ONLY;
} else version (Windows2003) {
	version = WIN32_WINNT_ONLY;
} else version (WindowsXP) {
	version = WIN32_WINNT_ONLY;
} else version (WindowsNTonly) {
	version = WIN32_WINNT_ONLY;
}
*/
public import win32.lmcons;
public import win32.lmaccess;
public import win32.lmalert;
public import win32.lmat;
public import win32.lmerr;
public import win32.lmshare;
public import win32.lmapibuf;
public import win32.lmremutl;
public import win32.lmrepl;
public import win32.lmuse;
public import win32.lmstats;
public import win32.lmwksta;
public import win32.lmserver;

version (Windows2000) {
} else {
	public import win32.lmmsg;
}

// FIXME: Everything in these next files seems to be deprecated!
import win32.lmaudit;
import win32.lmchdev; // can't find many docs for functions from this file.
import win32.lmconfig;
import win32.lmerrlog;
import win32.lmsvc;
import win32.lmsname; // in MinGW, this was publicly included by lm.lmsvc
