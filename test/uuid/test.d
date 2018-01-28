// test for duplicate symbols in druntime and uuid.lib
module test;

version(CRuntime_Microsoft) {} else static assert(false, "Windows/COFF only");

import core.sys.windows.basetyps;
import core.sys.windows.uuid;

extern extern(C) IID IID_IDelayedPropertyStoreFactory; // from uuid.lib

void main()
{
    assert(IID_IDirect3DNullDevice != IID_IDelayedPropertyStoreFactory);
}
