/**
 * Windows API header module
 *
 * Translated from MinGW API for MS-Windows 3.10
 *
 * Authors: Stewart Gordon
 * License: Placed into public domain
 * Source: $(DRUNTIMESRC src/core/sys/windows/_idispids.d)
 */
module core.sys.windows.idispids;

enum : int {
	DISPID_AMBIENT_OFFLINEIFNOTCONNECTED = -5501,
	DISPID_AMBIENT_SILENT                = -5502
}
