
/*
 * Hello Object DLL Self-Registering Server
 * Heavily modified from:
 */
/*
 * SELFREG.CPP
 * Server Self-Registrtation Utility, Chapter 5
 *
 * Copyright (c)1993-1995 Microsoft Corporation, All Rights Reserved
 *
 * Kraig Brockschmidt, Microsoft
 * Internet  :  kraigb@microsoft.com
 * Compuserve:  >INTERNET:kraigb@microsoft.com
 */

import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;
import std.string;
import core.sys.windows.com;
import core.sys.windows.winbase;
import core.sys.windows.windef;
import core.sys.windows.winreg;

import chello;

// This class factory object creates Hello objects.

class CHelloClassFactory : ComObject, IClassFactory
{
public:
    this()
    {
        printf("CHelloClassFactory()\n");
    }

    ~this()
    {
        printf("~CHelloClassFactory()");
    }

    extern (Windows) :

    // IUnknown members
    override HRESULT QueryInterface(const (IID)*riid, LPVOID *ppv)
    {
        printf("CHelloClassFactory.QueryInterface()\n");

        if (IID_IUnknown == *riid)
        {
            printf("IUnknown\n");
            *ppv = cast(void*) cast(IUnknown) this;
        }
        else if (IID_IClassFactory == *riid)
        {
            printf("IClassFactory\n");
            *ppv = cast(void*) cast(IClassFactory) this;
        }
        else
        {
            *ppv = null;
            return E_NOINTERFACE;
        }

        AddRef();
        return NOERROR;
    }

    // IClassFactory members
    override HRESULT CreateInstance(IUnknown pUnkOuter, IID*riid, LPVOID *ppvObj)
    {
        CHello  pObj;
        HRESULT hr;

        printf("CHelloClassFactory.CreateInstance()\n");
        *ppvObj = null;
        hr      = E_OUTOFMEMORY;

        // Verify that a controlling unknown asks for IUnknown
        if (null !is pUnkOuter && memcmp(&IID_IUnknown, riid, IID.sizeof))
            return CLASS_E_NOAGGREGATION;

        // Create the object passing function to notify on destruction.
        pObj = new CHello(pUnkOuter, &ObjectDestroyed);

        if (!pObj)
            return hr;

        if (pObj.Init())
        {
            hr = pObj.QueryInterface(riid, ppvObj);
        }

        // Kill the object if initial creation or Init failed.
        if (FAILED(hr))
            delete pObj;
        else
            g_cObj++;

        return hr;
    }

    HRESULT LockServer(BOOL fLock)
    {
        printf("CHelloClassFactory.LockServer(%d)\n", fLock);

        if (fLock)
            g_cLock++;
        else
            g_cLock--;

        return NOERROR;
    }
};

// Count number of objects and number of locks.
ULONG g_cObj =0;
ULONG g_cLock=0;

import core.sys.windows.dll;
HINSTANCE g_hInst;

extern (Windows):

BOOL DllMain(HINSTANCE hInstance, ULONG ulReason, LPVOID pvReserved)
{
    switch (ulReason)
    {
        case DLL_PROCESS_ATTACH:
            g_hInst = hInstance;
            dll_process_attach( hInstance, true );
            printf("ATTACH\n");
            version(CRuntime_DigitalMars) _fcloseallp = null; // https://issues.dlang.org/show_bug.cgi?id=1550
            break;

        case DLL_PROCESS_DETACH:
            printf("DETACH\n");
            dll_process_detach( hInstance, true );
            break;

        case DLL_THREAD_ATTACH:
            dll_thread_attach( true, true );
            printf("THREAD_ATTACH\n");
            break;

        case DLL_THREAD_DETACH:
            dll_thread_detach( true, true );
            printf("THREAD_DETACH\n");
            break;

        default:
            assert(0);
    }
    return true;
}

/*
 * DllGetClassObject
 *
 * Purpose:
 *  Provides an IClassFactory for a given CLSID that this DLL is
 *  registered to support.  This DLL is placed under the CLSID
 *  in the registration database as the InProcServer.
 *
 * Parameters:
 *  clsID           REFCLSID that identifies the class factory
 *                  desired.  Since this parameter is passed this
 *                  DLL can handle any number of objects simply
 *                  by returning different class factories here
 *                  for different CLSIDs.
 *
 *  riid            REFIID specifying the interface the caller wants
 *                  on the class object, usually IID_ClassFactory.
 *
 *  ppv             LPVOID * in which to return the interface
 *                  pointer.
 *
 * Return Value:
 *  HRESULT         NOERROR on success, otherwise an error code.
 */
HRESULT DllGetClassObject(CLSID*rclsid, IID*riid, LPVOID *ppv)
{
    HRESULT hr;
    CHelloClassFactory pObj;

    printf("DllGetClassObject()\n");

    if (CLSID_Hello != *rclsid)
        return E_FAIL;

    pObj = new CHelloClassFactory();

    if (!pObj)
        return E_OUTOFMEMORY;

    hr = pObj.QueryInterface(riid, ppv);

    if (FAILED(hr))
        delete pObj;

    return hr;
}

/*
 *  Answers if the DLL can be freed, that is, if there are no
 *  references to anything this DLL provides.
 *
 * Return Value:
 *  BOOL            true if nothing is using us, false otherwise.
 */
HRESULT DllCanUnloadNow()
{
    SCODE sc;

    printf("DllCanUnloadNow()\n");

    // Any locks or objects?
    sc = (0 == g_cObj && 0 == g_cLock) ? S_OK : S_FALSE;
    return sc;
}

/*
 *  Instructs the server to create its own registry entries
 *
 * Return Value:
 *  HRESULT         NOERROR if registration successful, error
 *                  otherwise.
 */
HRESULT DllRegisterServer()
{
    char[128] szID;
    char[128] szCLSID;
    char[512] szModule;

    printf("DllRegisterServer()\n");

    // Create some base key strings.
    StringFromGUID2(&CLSID_Hello, cast(LPOLESTR) szID, 128);
    unicode2ansi(szID.ptr);
    strcpy(szCLSID.ptr, "CLSID\\");
    strcat(szCLSID.ptr, szID.ptr);

    // Create ProgID keys
    SetKeyAndValue("Hello1.0", null, "Hello Object");
    SetKeyAndValue("Hello1.0", "CLSID", szID.ptr);

    // Create VersionIndependentProgID keys
    SetKeyAndValue("Hello", null, "Hello Object");
    SetKeyAndValue("Hello", "CurVer", "Hello1.0");
    SetKeyAndValue("Hello", "CLSID", szID.ptr);

    // Create entries under CLSID
    SetKeyAndValue(szCLSID.ptr, null, "Hello Object");
    SetKeyAndValue(szCLSID.ptr, "ProgID", "Hello1.0");
    SetKeyAndValue(szCLSID.ptr, "VersionIndependentProgID", "Hello");
    SetKeyAndValue(szCLSID.ptr, "NotInsertable", null);

    GetModuleFileNameA(g_hInst, szModule.ptr, szModule.length);

    SetKeyAndValue(szCLSID.ptr, "InprocServer32", szModule.ptr);
    return NOERROR;
}

/*
 * Purpose:
 *  Instructs the server to remove its own registry entries
 *
 * Return Value:
 *  HRESULT         NOERROR if registration successful, error
 *                  otherwise.
 */
HRESULT DllUnregisterServer()
{
    char[128] szID;
    char[128] szCLSID;
    char[256] szTemp;

    printf("DllUnregisterServer()\n");

    // Create some base key strings.
    StringFromGUID2(&CLSID_Hello, cast(LPOLESTR) szID, 128);
    unicode2ansi(szID.ptr);
    strcpy(szCLSID.ptr, "CLSID\\");
    strcat(szCLSID.ptr, szID.ptr);

    RegDeleteKeyA(HKEY_CLASSES_ROOT, "Hello\\CurVer");
    RegDeleteKeyA(HKEY_CLASSES_ROOT, "Hello\\CLSID");
    RegDeleteKeyA(HKEY_CLASSES_ROOT, "Hello");

    RegDeleteKeyA(HKEY_CLASSES_ROOT, "Hello1.0\\CLSID");
    RegDeleteKeyA(HKEY_CLASSES_ROOT, "Hello1.0");

    strcpy(szTemp.ptr, szCLSID.ptr);
    strcat(szTemp.ptr, "\\");
    strcat(szTemp.ptr, "ProgID");
    RegDeleteKeyA(HKEY_CLASSES_ROOT, szTemp.ptr);

    strcpy(szTemp.ptr, szCLSID.ptr);
    strcat(szTemp.ptr, "\\");
    strcat(szTemp.ptr, "VersionIndependentProgID");
    RegDeleteKeyA(HKEY_CLASSES_ROOT, szTemp.ptr);

    strcpy(szTemp.ptr, szCLSID.ptr);
    strcat(szTemp.ptr, "\\");
    strcat(szTemp.ptr, "NotInsertable");
    RegDeleteKeyA(HKEY_CLASSES_ROOT, szTemp.ptr);

    strcpy(szTemp.ptr, szCLSID.ptr);
    strcat(szTemp.ptr, "\\");
    strcat(szTemp.ptr, "InprocServer32");
    RegDeleteKeyA(HKEY_CLASSES_ROOT, szTemp.ptr);

    RegDeleteKeyA(HKEY_CLASSES_ROOT, szCLSID.ptr);
    return NOERROR;
}

/*
 * SetKeyAndValue
 *
 * Purpose:
 *  Private helper function for DllRegisterServer that creates
 *  a key, sets a value, and closes that key.
 *
 * Parameters:
 *  pszKey          LPTSTR to the name of the key
 *  pszSubkey       LPTSTR ro the name of a subkey
 *  pszValue        LPTSTR to the value to store
 *
 * Return Value:
 *  BOOL            true if successful, false otherwise.
 */
BOOL SetKeyAndValue(LPCSTR pszKey, LPCSTR pszSubkey, LPCSTR pszValue)
{
    HKEY hKey;
    char[256] szKey;
    BOOL result;

    strcpy(szKey.ptr, pszKey);

    if (pszSubkey)
    {
        strcat(szKey.ptr, "\\");
        strcat(szKey.ptr, pszSubkey);
    }

    result = true;

    int regresult = RegCreateKeyExA(HKEY_CLASSES_ROOT,
                                          szKey.ptr, 0, null, REG_OPTION_NON_VOLATILE,
                                          KEY_ALL_ACCESS, null, &hKey, null);
    if (ERROR_SUCCESS != regresult)
    {
        result = false;
        // If the value is 5, you'll need to run the program with Administrator privileges
        printf("RegCreateKeyExA() failed with 0x%x\n", regresult);
    }
    else
    {
        if (null != pszValue)
        {
            if (RegSetValueExA(hKey, null, 0, REG_SZ, cast(BYTE *) pszValue,
                               cast(int)((strlen(pszValue) + 1) * char.sizeof)) != ERROR_SUCCESS)
                result = false;
        }

        if (RegCloseKey(hKey) != ERROR_SUCCESS)
            result = false;
    }

    if (!result)
        printf("SetKeyAndValue() failed\n");

    return result;
}

/*
 * ObjectDestroyed
 *
 * Purpose:
 *  Function for the Hello object to call when it gets destroyed.
 *  Since we're in a DLL we only track the number of objects here,
 *  letting DllCanUnloadNow take care of the rest.
 */

extern (D) void ObjectDestroyed()
{
    printf("ObjectDestroyed()\n");
    g_cObj--;
}

void unicode2ansi(char *s)
{
    wchar *w;

    for (w = cast(wchar *) s; *w; w++)
        *s++ = cast(char)*w;

    *s = 0;
}
