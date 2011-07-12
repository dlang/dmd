/**
 * This module provides OS specific helper function for threads support
 *
 * Copyright: Copyright Digital Mars 2010 - 2010.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Rainer Schuetze
 */

/*          Copyright Digital Mars 2010 - 2010.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */

module core.sys.windows.threadaux;

version( Windows )
{
    import core.sys.windows.windows;
    import core.stdc.stdlib;

    public import core.thread;

    extern(Windows)
    HANDLE OpenThread(DWORD dwDesiredAccess, BOOL bInheritHandle, DWORD dwThreadId);

    extern (C) extern __gshared int _tls_index;

private:
    ///////////////////////////////////////////////////////////////////
    struct thread_aux
    {
        // don't let symbols leak into other modules

        enum SystemProcessInformation = 5;
        enum STATUS_INFO_LENGTH_MISMATCH = 0xc0000004;

        // abbreviated versions of these structs (full info can be found
        //  here: http://undocumented.ntinternals.net )
        struct _SYSTEM_PROCESS_INFORMATION
        {
            int NextEntryOffset; // When this entry is 0, there are no more processes to be read.
            int NumberOfThreads;
            int[15] fill1;
            int ProcessId;
            int[28] fill2;

            // SYSTEM_THREAD_INFORMATION or SYSTEM_EXTENDED_THREAD_INFORMATION structures follow.
        }

        struct _SYSTEM_THREAD_INFORMATION
        {
            int[8] fill1;
            int ProcessId;
            int ThreadId;
            int[6] fill2;
        }

        alias extern(Windows)
        HRESULT fnNtQuerySystemInformation( uint SystemInformationClass, void* info, uint infoLength, uint* ReturnLength );

        enum ThreadBasicInformation = 0;

        struct THREAD_BASIC_INFORMATION
        {
            int    ExitStatus;
            void** TebBaseAddress;
            int    ProcessId;
            int    ThreadId;
            int    AffinityMask;
            int    Priority;
            int    BasePriority;
        }

        alias extern(Windows)
        int fnNtQueryInformationThread( HANDLE ThreadHandle, uint ThreadInformationClass, void* buf, uint size, uint* ReturnLength );

        enum SYNCHRONIZE = 0x00100000;
        enum THREAD_GET_CONTEXT = 8;
        enum THREAD_QUERY_INFORMATION = 0x40;
        enum THREAD_SUSPEND_RESUME = 2;

        ///////////////////////////////////////////////////////////////////
        // get the thread environment block (TEB) of the thread with the given handle
        static void** getTEB( HANDLE hnd )
        {
            HANDLE nthnd = GetModuleHandleA( "NTDLL" );
            assert( nthnd, "cannot get module handle for ntdll" );
            fnNtQueryInformationThread* fn = cast(fnNtQueryInformationThread*) GetProcAddress( nthnd, "NtQueryInformationThread" );
            assert( fn, "cannot find NtQueryInformationThread in ntdll" );

            THREAD_BASIC_INFORMATION tbi;
            int Status = (*fn)(hnd, ThreadBasicInformation, &tbi, tbi.sizeof, null);
            assert(Status == 0);

            return tbi.TebBaseAddress;
        }

        // get the thread environment block (TEB) of the thread with the given identifier
        static void** getTEB( uint id )
        {
            HANDLE hnd = OpenThread( THREAD_QUERY_INFORMATION, FALSE, id );
            assert( hnd, "OpenThread failed" );

            void** teb = getTEB( hnd );
            CloseHandle( hnd );
            return teb;
        }

        // get linear address of TEB of current thread
        static void** getTEB()
        {
            asm
            {
                naked;
                mov EAX,FS:[0x18];
                ret;
            }
        }

        // get the stack bottom (the top address) of the thread with the given handle
        static void* getThreadStackBottom( HANDLE hnd )
        {
            void** teb = getTEB( hnd );
            return teb[1];
        }

        // get the stack bottom (the top address) of the thread with the given identifier
        static void* getThreadStackBottom( uint id )
        {
            void** teb = getTEB( id );
            return teb[1];
        }

        // create a thread handle with full access to the thread with the given identifier
        static HANDLE OpenThreadHandle( uint id )
        {
            return OpenThread( SYNCHRONIZE|THREAD_GET_CONTEXT|THREAD_QUERY_INFORMATION|THREAD_SUSPEND_RESUME, FALSE, id );
        }

        ///////////////////////////////////////////////////////////////////
        // enumerate threads of the given process calling the passed function on each thread
        // using function instead of delegate here to avoid allocating closure
        static bool enumProcessThreads( uint procid, bool function( uint id, void* context ) dg, void* context )
        {
            HANDLE hnd = GetModuleHandleA( "NTDLL" );
            fnNtQuerySystemInformation* fn = cast(fnNtQuerySystemInformation*) GetProcAddress( hnd, "NtQuerySystemInformation" );
            if( !fn )
                return false;

            uint sz = 16384;
            uint retLength;
            HRESULT rc;
            char* buf;
            for( ; ; )
            {
                buf = cast(char*) core.stdc.stdlib.malloc(sz);
                if(!buf)
                    return false;
                rc = (*fn)( SystemProcessInformation, buf, sz, &retLength );
                if( rc != STATUS_INFO_LENGTH_MISMATCH )
                    break;
                core.stdc.stdlib.free( buf );
                sz *= 2;
            }
            scope(exit) core.stdc.stdlib.free( buf );

            if(rc != 0)
                return false;

            auto pinfo = cast(_SYSTEM_PROCESS_INFORMATION*) buf;
            auto pend  = cast(_SYSTEM_PROCESS_INFORMATION*) (buf + retLength);
            for( ; pinfo < pend; )
            {
                if( pinfo.ProcessId == procid )
                {
                    auto tinfo = cast(_SYSTEM_THREAD_INFORMATION*)(pinfo + 1);
                    for( int i = 0; i < pinfo.NumberOfThreads; i++, tinfo++ )
                        if( tinfo.ProcessId == procid )
                            if( !dg( tinfo.ThreadId, context ) )
                                return false;
                }
                if( pinfo.NextEntryOffset == 0 )
                    break;
                pinfo = cast(_SYSTEM_PROCESS_INFORMATION*) (cast(char*) pinfo + pinfo.NextEntryOffset);
            }
            return true;
        }

        static bool enumProcessThreads( bool function( uint id, void* context ) dg, void* context )
        {
            return enumProcessThreads( GetCurrentProcessId(), dg, context );
        }

        // execute function on the TLS for the given thread
        alias extern(C) void function() externCVoidFunc;
        static void impersonate_thread( uint id, externCVoidFunc fn )
        {
            if( id == GetCurrentThreadId() )
            {
                fn();
                return;
            }

            // temporarily set current TLS array pointer to the array pointer of the referenced thread
            void** curteb = getTEB();
            void** teb    = getTEB( id );
            assert( teb && curteb );

            void** curtlsarray = cast(void**) curteb[11];
            void** tlsarray    = cast(void**) teb[11];
            if( !curtlsarray || !tlsarray )
                return;

            curteb[11] = tlsarray;
            fn();
            curteb[11] = curtlsarray;
        }
    }

public:
    // forward as few symbols as possible into the "global" name space
    alias thread_aux.getTEB getTEB;
    alias thread_aux.getThreadStackBottom getThreadStackBottom;
    alias thread_aux.OpenThreadHandle OpenThreadHandle;
    alias thread_aux.enumProcessThreads enumProcessThreads;

    // get the start of the TLS memory of the thread with the given handle
    void* GetTlsDataAddress( HANDLE hnd )
    {
        if( void** teb = getTEB( hnd ) )
            if( void** tlsarray = cast(void**) teb[11] )
                return tlsarray[_tls_index];
        return null;
    }

    // get the start of the TLS memory of the thread with the given identifier
    void* GetTlsDataAddress( uint id )
    {
        HANDLE hnd = OpenThread( thread_aux.THREAD_QUERY_INFORMATION, FALSE, id );
        assert( hnd, "OpenThread failed" );

        void* tls = GetTlsDataAddress( hnd );
        CloseHandle( hnd );
        return tls;
    }

    ///////////////////////////////////////////////////////////////////
    // run _moduleTlsCtor in the context of the given thread
    void thread_moduleTlsCtor( uint id )
    {
        thread_aux.impersonate_thread(id, &_moduleTlsCtor);
    }

    ///////////////////////////////////////////////////////////////////
    // run _moduleTlsDtor in the context of the given thread
    void thread_moduleTlsDtor( uint id )
    {
        thread_aux.impersonate_thread(id, &_moduleTlsDtor);
    }
}

