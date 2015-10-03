/***********************************************************************\
*                              lmconfig.d                               *
*                                                                       *
*                       Windows API header module                       *
*                                                                       *
*                 Translated from MinGW Windows headers                 *
*                                                                       *
*                       Placed into public domain                       *
\***********************************************************************/
module core.sys.windows.lmconfig;

// All functions in this file are deprecated!

private import core.sys.windows.lmcons, core.sys.windows.windef;

deprecated {
	struct CONFIG_INFO_0 {
		LPWSTR cfgi0_key;
		LPWSTR cfgi0_data;
	}

	alias CONFIG_INFO_0* PCONFIG_INFO_0, LPCONFIG_INFO_0;

	extern (Windows) {
		NET_API_STATUS NetConfigGet(LPCWSTR, LPCWSTR, LPCWSTR, PBYTE*);
		NET_API_STATUS NetConfigGetAll(LPCWSTR, LPCWSTR, PBYTE*);
		NET_API_STATUS NetConfigSet(LPCWSTR, LPCWSTR, LPCWSTR, DWORD, DWORD,
		  PBYTE, DWORD);
	}
}
