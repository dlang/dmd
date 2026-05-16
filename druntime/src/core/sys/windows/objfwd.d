/**
 * Windows API header module
 *
 * Translated from MinGW Windows headers
 *
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source: $(DRUNTIMESRC core/sys/windows/_objfwd.d)
 */
module core.sys.windows.objfwd;
version (Windows):

import core.sys.windows.objidl;

/+
// Forward declararions are not necessary in D.
extern(Windows) {
    interface IMoniker;
    interface IStream;
    interface IMarshal;
    interface IMalloc;
    interface IMallocSpy;
    interface IMessageFilter;
    interface IPersist;
    interface IPersistStream;
    interface IRunningObjectTable;
    interface IBindCtx;
    interface IAdviseSink;
    interface IAdviseSink2;
    interface IDataObject;
    interface IDataAdviseHolder;

    interface IEnumMoniker;
    interface IEnumFORMATETC;
    interface IEnumSTATDATA;
    interface IEnumSTATSTG;
    interface IEnumSTATPROPSTG;
    interface IEnumString;
    interface IEnumUnknown;
    interface IStorage;
    interface IPersistStorage;
    interface ILockBytes;
    interface IStdMarshalInfo;
    interface IExternalConnection;
    interface IRunnableObject;
    interface IROTData;
    interface IPersistFile;
    interface IRootStorage;
    interface IPropertyStorage;
    interface IEnumSTATPROPSETSTG;
    interface IPropertySetStorage;
    interface IClientSecurity;
    interface IServerSecurity;
    interface IClassActivator;
    interface IFillLockBytes;
    interface IProgressNotify;
    interface ILayoutStorage;
    interface IRpcProxyBuffer;
    interface IRpcChannelBuffer;
    interface IRpcStubBuffer;
}
+/
alias LPMONIKER = IMoniker;
alias LPSTREAM = IStream;
alias LPMARSHAL = IMarshal;
alias LPMALLOC = IMalloc;
alias LPMALLOCSPY = IMallocSpy;
alias LPMESSAGEFILTER = IMessageFilter;
alias LPPERSIST = IPersist;
alias LPPERSISTSTREAM = IPersistStream;
alias LPRUNNINGOBJECTTABLE = IRunningObjectTable;
alias LPBINDCTX = IBindCtx, LPBC = IBindCtx;
alias LPADVISESINK = IAdviseSink;
alias LPADVISESINK2 = IAdviseSink2;
alias LPDATAOBJECT = IDataObject;
alias LPDATAADVISEHOLDER = IDataAdviseHolder;
alias LPENUMMONIKER = IEnumMoniker;
alias LPENUMFORMATETC = IEnumFORMATETC;
alias LPENUMSTATDATA = IEnumSTATDATA;
alias LPENUMSTATSTG = IEnumSTATSTG;
alias LPENUMSTATPROPSTG = IEnumSTATPROPSTG;
alias LPENUMSTRING = IEnumString;
alias LPENUMUNKNOWN = IEnumUnknown;
alias LPSTORAGE = IStorage;
alias LPPERSISTSTORAGE = IPersistStorage;
alias LPLOCKBYTES = ILockBytes;
alias LPSTDMARSHALINFO = IStdMarshalInfo;
alias LPEXTERNALCONNECTION = IExternalConnection;
alias LPRUNNABLEOBJECT = IRunnableObject;
alias LPROTDATA = IROTData;
alias LPPERSISTFILE = IPersistFile;
alias LPROOTSTORAGE = IRootStorage;
alias LPRPCCHANNELBUFFER = IRpcChannelBuffer;
alias LPRPCPROXYBUFFER = IRpcProxyBuffer;
alias LPRPCSTUBBUFFER = IRpcStubBuffer;
alias LPPROPERTYSTORAGE = IPropertyStorage;
alias LPENUMSTATPROPSETSTG = IEnumSTATPROPSETSTG;
alias LPPROPERTYSETSTORAGE = IPropertySetStorage;
alias LPCLIENTSECURITY = IClientSecurity;
alias LPSERVERSECURITY = IServerSecurity;
alias LPCLASSACTIVATOR = IClassActivator;
alias LPFILLLOCKBYTES = IFillLockBytes;
alias LPPROGRESSNOTIFY = IProgressNotify;
alias LPLAYOUTSTORAGE = ILayoutStorage;
