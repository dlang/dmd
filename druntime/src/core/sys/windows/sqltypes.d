/**
$(RED Warning:
      This binding is out-of-date and does not allow use on non-Windows platforms. Use `etc.c.odbc.sqltypes` instead.)

 * Windows API header module
 *
 * Translated from MinGW Windows headers
 *
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source: $(DRUNTIMESRC core/sys/windows/_sqltypes.d)
 */

module core.sys.windows.sqltypes;
version (Windows):

version (ANSI) {} else version = Unicode;

/* Conversion notes:
  It's assumed that ODBC >= 0x0300.
*/

import core.sys.windows.windef;
import core.sys.windows.basetyps; // for GUID

alias SCHAR = byte, SQLSCHAR = byte;
alias SDWORD = int, SLONG = int, SQLINTEGER = int;
alias SWORD = short, SSHORT = short, RETCODE = short, SQLSMALLINT = short;
alias UDWORD = ULONG;
alias UWORD = USHORT, SQLUSMALLINT = USHORT;
alias SDOUBLE = double, LDOUBLE = double;
alias SFLOAT = float;
alias PTR = PVOID, HENV = PVOID, HDBC = PVOID, HSTMT = PVOID, SQLPOINTER = PVOID;
alias SQLCHAR = UCHAR;
// #ifndef _WIN64
alias SQLUINTEGER = UDWORD;
// #endif

//static if (ODBCVER >= 0x0300) {
alias SQLHANDLE = HANDLE;
alias SQLHENV = SQLHANDLE, SQLHDBC = SQLHANDLE, SQLHSTMT = SQLHANDLE, SQLHDESC = SQLHANDLE;
/*
} else {
alias void* SQLHENV;
alias void* SQLHDBC;
alias void* SQLHSTMT;
}
*/
alias SQLRETURN = SQLSMALLINT;
alias SQLHWND = HWND;
alias BOOKMARK = ULONG;

alias SQLLEN = SQLINTEGER, SQLROWOFFSET = SQLINTEGER;
alias SQLROWCOUNT = SQLUINTEGER, SQLULEN = SQLUINTEGER;
alias SQLTRANSID = DWORD;
alias SQLSETPOSIROW = SQLUSMALLINT;
alias SQLWCHAR = wchar;

version (Unicode) {
    alias SQLTCHAR = SQLWCHAR;
} else {
    alias SQLTCHAR = SQLCHAR;
}
//static if (ODBCVER >= 0x0300) {
alias SQLDATE = ubyte, SQLDECIMAL = ubyte;
alias SQLDOUBLE = double, SQLFLOAT = double;
alias SQLNUMERIC = ubyte;
alias SQLREAL = float;
alias SQLTIME = ubyte, SQLTIMESTAMP = ubyte, SQLVARCHAR = ubyte;
alias ODBCINT64 = long, SQLBIGINT = long;
alias SQLUBIGINT = ulong;
//}

//Everything above this line may by used by odbcinst.d
//Everything below this line is deprecated
deprecated ("The ODBC 3.5 modules are deprecated. Please use the ODBC4 modules in the `etc.c.odbc` package."):

struct DATE_STRUCT {
    SQLSMALLINT year;
    SQLUSMALLINT month;
    SQLUSMALLINT day;
}

struct TIME_STRUCT {
    SQLUSMALLINT hour;
    SQLUSMALLINT minute;
    SQLUSMALLINT second;
}

struct TIMESTAMP_STRUCT {
    SQLSMALLINT year;
    SQLUSMALLINT month;
    SQLUSMALLINT day;
    SQLUSMALLINT hour;
    SQLUSMALLINT minute;
    SQLUSMALLINT second;
    SQLUINTEGER fraction;
}

//static if (ODBCVER >= 0x0300) {
alias SQL_DATE_STRUCT = DATE_STRUCT;
alias SQL_TIME_STRUCT = TIME_STRUCT;
alias SQL_TIMESTAMP_STRUCT = TIMESTAMP_STRUCT;

enum SQLINTERVAL {
    SQL_IS_YEAR = 1,
    SQL_IS_MONTH,
    SQL_IS_DAY,
    SQL_IS_HOUR,
    SQL_IS_MINUTE,
    SQL_IS_SECOND,
    SQL_IS_YEAR_TO_MONTH,
    SQL_IS_DAY_TO_HOUR,
    SQL_IS_DAY_TO_MINUTE,
    SQL_IS_DAY_TO_SECOND,
    SQL_IS_HOUR_TO_MINUTE,
    SQL_IS_HOUR_TO_SECOND,
    SQL_IS_MINUTE_TO_SECOND
}

struct SQL_YEAR_MONTH_STRUCT {
    SQLUINTEGER year;
    SQLUINTEGER month;
}

struct SQL_DAY_SECOND_STRUCT {
    SQLUINTEGER day;
    SQLUINTEGER hour;
    SQLUINTEGER minute;
    SQLUINTEGER second;
    SQLUINTEGER fraction;
}

struct SQL_INTERVAL_STRUCT {
    SQLINTERVAL interval_type;
    SQLSMALLINT interval_sign;
    union _intval {
        SQL_YEAR_MONTH_STRUCT year_month;
        SQL_DAY_SECOND_STRUCT day_second;
    }
    _intval intval;
}

enum SQL_MAX_NUMERIC_LEN = 16;

struct SQL_NUMERIC_STRUCT {
    SQLCHAR precision;
    SQLSCHAR scale;
    SQLCHAR sign;
    SQLCHAR[SQL_MAX_NUMERIC_LEN] val;
}
// } ODBCVER >= 0x0300
alias SQLGUID = GUID;
