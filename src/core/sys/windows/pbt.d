/***********************************************************************\
*                                  pbt.d                                *
*                                                                       *
*                       Windows API header module                       *
*                                                                       *
*                 Translated from MinGW Windows headers                 *
*                           by Stewart Gordon                           *
*                                                                       *
*                       Placed into public domain                       *
\***********************************************************************/
module win32.pbt;

private import win32.windef;

enum : WPARAM {
	PBT_APMQUERYSUSPEND,
	PBT_APMQUERYSTANDBY,
	PBT_APMQUERYSUSPENDFAILED,
	PBT_APMQUERYSTANDBYFAILED,
	PBT_APMSUSPEND,
	PBT_APMSTANDBY,
	PBT_APMRESUMECRITICAL,
	PBT_APMRESUMESUSPEND,
	PBT_APMRESUMESTANDBY,
	PBT_APMBATTERYLOW,
	PBT_APMPOWERSTATUSCHANGE,
	PBT_APMOEMEVENT // = 11
}

const LPARAM PBTF_APMRESUMEFROMFAILURE = 1;
