/**
 * Windows API header module
 *
 * Translated from MinGW API for MS-Windows 3.10
 *
 * License: Placed into public domain
 * Source: $(DRUNTIMESRC src/core/sys/windows/_servprov.d)
 */
module core.sys.windows.servprov;

private import core.sys.windows.basetyps, core.sys.windows.unknwn, core.sys.windows.windef, core.sys.windows.wtypes;

interface IServiceProvider : IUnknown {
    HRESULT QueryService(REFGUID, REFIID, void**);
}
