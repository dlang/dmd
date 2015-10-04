/**
 * Windows API header module
 *
 * Translated from MinGW Windows headers
 *
 * License: Placed into public domain
 * Source: $(DRUNTIMESRC src/core/sys/windows/_lmcons.d)
 */
module core.sys.windows.lmcons;
version (Windows):

private import core.sys.windows.windef;
private import core.sys.windows.lmerr; // for NERR_BASE

const TCHAR[]
    MESSAGE_FILENAME = "NETMSG",
    OS2MSG_FILENAME = "BASE",
    HELP_MSG_FILENAME = "NETH";

alias DWORD NET_API_STATUS, API_RET_TYPE;

const MIN_LANMAN_MESSAGE_ID = NERR_BASE;
const MAX_LANMAN_MESSAGE_ID = 5799;

const CNLEN        = 15; /* also in nddeapi.h */
const UNCLEN       = CNLEN + 2;

const DNLEN        = 15;
const LM20_CNLEN   = 15;
const LM20_DNLEN   = 15;
const LM20_SNLEN   = 15;
const LM20_STXTLEN = 63;
const LM20_UNCLEN  = LM20_CNLEN + 2;
const LM20_NNLEN   = 12;
const LM20_RMLEN   = LM20_UNCLEN + 1 + LM20_NNLEN;
const NNLEN        = 80;
const RMLEN        = UNCLEN + 1 + NNLEN;
const SNLEN        = 80;
const STXTLEN      = 256;
const PATHLEN      = 256;
const LM20_PATHLEN = 256;
const DEVLEN       = 80;
const LM20_DEVLEN  = 8;
const EVLEN        = 16;
const UNLEN        = 256;
const LM20_UNLEN   = 20;
const GNLEN        = UNLEN;
const LM20_GNLEN   = LM20_UNLEN;
const PWLEN        = 256;
const LM20_PWLEN   = 14;
const SHPWLEN      = 8;
const CLTYPE_LEN   = 12;
const QNLEN        = NNLEN;
const LM20_QNLEN   = LM20_NNLEN;

const MAXCOMMENTSZ = 256;
const LM20_MAXCOMMENTSZ = 48;
const ALERTSZ      = 128;
const MAXDEVENTRIES = 32;// (sizeof(int)*8);
const NETBIOS_NAME_LEN = 16;
const DWORD MAX_PREFERRED_LENGTH = -1;
const CRYPT_KEY_LEN = 7;
const CRYPT_TXT_LEN = 8;
const ENCRYPTED_PWLEN = 16;
const SESSION_PWLEN = 24;
const SESSION_CRYPT_KLEN = 21;

const PARMNUM_ALL = 0;
const DWORD PARM_ERROR_UNKNOWN = -1;
const PARM_ERROR_NONE = 0;
const PARMNUM_BASE_INFOLEVEL = 1000;

const PLATFORM_ID_DOS = 300;
const PLATFORM_ID_OS2 = 400;
const PLATFORM_ID_NT  = 500;
const PLATFORM_ID_OSF = 600;
const PLATFORM_ID_VMS = 700;

// this is a new typedef in W2K, but it should be harmless for earlier Windows versions.
version (Unicode) {
    alias LPWSTR LMSTR;
    alias LPCWSTR LMCSTR;
} else {
    alias LPSTR LMSTR;
    alias LPCSTR LMCSTR;
}
