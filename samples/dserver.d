
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
import core.sys.windows.windows;
import core.sys.windows.com;

import chello;

// This class factory object creates Hello objects.

class CHelloClassFactory : ComObject, IClassFactory
{
public:
    this()
    {
        MessageBoxA(null, "CHelloClassFactory()", null, MB_OK);
    }

    ~this()
    {
        MessageBoxA(null, "~CHelloClassFactory()", null, MB_OK);
    }

    extern (Windows) :

    // IUnknown members
    override HRESULT QueryInterface(const (IID)*riid, LPVOID *ppv)
    {
        MessageBoxA(null, "CHelloClassFactory.QueryInterface()", null, MB_OK);

        if (IID_IUnknown == *riid)
        {
            MessageBoxA(null, "IUnknown", null, MB_OK);
            *ppv = cast(void*) cast(IUnknown) this;
        }
        else if (IID_IClassFactory == *riid)
        {
            MessageBoxA(null, "IClassFactory", null, MB_OK);
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

        MessageBoxA(null, "CHelloClassFactory.CreateInstance()", null, MB_OK);
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
        MessageBoxA(null, "CHelloClassFactory.LockServer()", null, MB_OK);

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

HINSTANCE g_hInst;

extern (C)
{
void *_atopsp;
void gc_init();
void gc_term();
void _minit();
void _moduleCtor();
void _moduleUnitTests();
}

extern (Windows) :

BOOL DllMain(HINSTANCE hInstance, ULONG ulReason, LPVOID pvReserved)
{
    // _atopsp = (void*)&hInstance;

    switch (ulReason)
    {
        case DLL_PROCESS_ATTACH:
            gc_init();
            _minit();
            _moduleCtor();

            //      _moduleUnitTests();
            MessageBoxA(null, "ATTACH", null, MB_OK);
            break;

        case DLL_PROCESS_DETACH:
            MessageBoxA(null, "DETACH", null, MB_OK);
            gc_term();
            break;

        case DLL_THREAD_ATTACH:
        case DLL_THREAD_DETACH:

            // Multiple threads not supported yet
            MessageBoxA(null, "THREAD", null, MB_OK);
            return false;

        default:
            assert(0);
    }

    g_hInst=hInstance;
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

    MessageBoxA(null, "DllGetClassObject()", null, MB_OK);

    // printf("DllGetClassObject()\n");

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

    MessageBoxA(null, "DllCanUnloadNow()", null, MB_OK);

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
    char szID[128];
    char szCLSID[128];
    char szModule[512];

    MessageBoxA(null, "DllRegisterServer()", null, MB_OK);

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
    char szID[128];
    char szCLSID[128];
    char szTemp[256];

    MessageBoxA(null, "DllUnregisterServer()", null, MB_OK);

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
    char szKey[256];
    BOOL result;

    strcpy(szKey.ptr, pszKey);

    if (pszSubkey)
    {
        strcat(szKey.ptr, "\\");
        strcat(szKey.ptr, pszSubkey);
    }

    result = true;

    if (ERROR_SUCCESS != RegCreateKeyExA(HKEY_CLASSES_ROOT,
                                          szKey.ptr, 0, null, REG_OPTION_NON_VOLATILE,
                                          KEY_ALL_ACCESS, null, &hKey, null))
        result = false;
    else
    {
        if (null != pszValue)
        {
            if (RegSetValueExA(hKey, null, 0, REG_SZ, cast(BYTE *) pszValue,
                               (strlen(pszValue) + 1) * char.sizeof) != ERROR_SUCCESS)
                result = false;
        }

        if (RegCloseKey(hKey) != ERROR_SUCCESS)
            result = false;
    }

    if (!result)
        MessageBoxA(null, "SetKeyAndValue() failed", null, MB_OK);

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
    MessageBoxA(null, "ObjectDestroyed()", null, MB_OK);
    g_cObj--;
}

void unicode2ansi(char *s)
{
    wchar *w;

    for (w = cast(wchar *) s; *w; w++)
        *s++ = cast(char)*w;

    *s = 0;
}

extern (C) int printf(char *format, ...)
{
    return 0;
}
