
/* Server for IHello
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

// From an example from "Inside OLE" Copyright Microsoft

import core.stdc.stdio;
import core.stdc.stdlib;
import std.string;
import core.sys.windows.com;
import core.sys.windows.windef;

GUID CLSID_Hello = { 0x30421140, 0, 0, [0xC0, 0, 0, 0, 0, 0, 0, 0x46] };
GUID IID_IHello  = { 0x00421140, 0, 0, [0xC0, 0, 0, 0, 0, 0, 0, 0x46] };

interface IHello : IUnknown
{
    extern (Windows) :
    int Print();
}

// Type for an object-destroyed callback
alias void function() PFNDESTROYED;

/*
 * The class definition for an object that singly implements
 * IHello in D.
 */
class CHello : ComObject, IHello
{
protected:
    IUnknown m_pUnkOuter;       // Controlling unknown

    PFNDESTROYED m_pfnDestroy;          // To call on closure

    /*
     *  pUnkOuter       LPUNKNOWN of a controlling unknown.
     *  pfnDestroy      PFNDESTROYED to call when an object
     *                  is destroyed.
     */
    public this(IUnknown pUnkOuter, PFNDESTROYED pfnDestroy)
    {
    m_pUnkOuter  = pUnkOuter;
    m_pfnDestroy = pfnDestroy;
    }

    ~this()
    {
        printf("CHello.~this()\n");
    }

    extern (Windows) :
    /*
     *  Performs any initialization of a CHello that's prone to failure
     *  that we also use internally before exposing the object outside.
     * Return Value:
     *  BOOL            true if the function is successful,
     *                  false otherwise.
     */

public:
    BOOL Init()
    {
        printf("CHello.Init()\n");
        return true;
    }

public:
    override HRESULT QueryInterface(const (IID)*riid, LPVOID *ppv)
    {
        printf("CHello.QueryInterface()\n");

        if (IID_IUnknown == *riid)
            *ppv = cast(void*) cast(IUnknown) this;
        else if (IID_IHello == *riid)
            *ppv = cast(void*) cast(IHello) this;
        else
        {
            *ppv = null;
            return E_NOINTERFACE;
        }

        AddRef();
        return NOERROR;
    }

    override ULONG Release()
    {
        printf("CHello.Release()\n");

        if (0 != --count)
            return count;

        /*
         * Tell the housing that an object is going away so it can
         * shut down if appropriate.
         */
        printf("CHello Destroy()\n");

        if (m_pfnDestroy)
            (*m_pfnDestroy)();

        // delete this;
        return 0;
    }

    // IHello members
    override HRESULT Print()
    {
        printf("CHello.Print()\n");
        return NOERROR;
    }
}
