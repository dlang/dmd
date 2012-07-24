/**
 * D header file for POSIX.
 *
 * Copyright: Copyright Sean Kelly 2005 - 2009.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Sean Kelly
 * Standards: The Open Group Base Specifications Issue 6, IEEE Std 1003.1, 2004 Edition
 */

/*          Copyright Sean Kelly 2005 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module core.sys.posix.config;

public import core.stdc.config;

extern (C):

version( linux )
{
    enum bool  __USE_LARGEFILE64    = true;
    enum bool  __USE_FILE_OFFSET64  = __USE_LARGEFILE64;
    enum bool  __REDIRECT           = false;
    enum bool  __USE_XOPEN2K8		= true; //#if (_POSIX_C_SOURCE - 0) >= 200809L
    enum bool _BSD_SOURCE			= true; /// Seems to be default in gcc.
    enum bool _SVID_SOURCE   		= true; /// Ditto
    enum bool __USE_GNU				= true;
    static if(_BSD_SOURCE || _SVID_SOURCE) {
    	enum bool __USE_MISC			= true; 
    }

    // Word sizes:
    version(X86) {
        enum __WORDSIZE=32;
    }

    version(X86_64) {
    	enum __WORDSIZE=64;
    }

    version(ARM) {
    	enum __WORDSIZE=32;
    }

    version(PPC) {
    	enum __WORDSIZE=32;
    }

    version(PPC64) {
    	enum __WORDSIZE=64;
    }

    version(IA64) {
    	enum __WORDSIZE=64;
    }

    version(MIPS) {
    	enum __WORDSIZE=32;
    }

    version(MIPS6) {
    	enum __WORDSIZE=64;
    }

    version(SPARC) {
    	enum __WORDSIZE=32;
    }

    version(SPARC64) {
    	enum __WORDSIZE=64;
    }

    version(S390) {
    	enum __WORDSIZE=32;
    }

    version(S390X) {
    	enum __WORDSIZE=64;
    }

    version(HPPA) {
    	enum __WORDSIZE=32;
    }

    version(HPPA6) {
    	enum __WORDSIZE=64;
    }

    version(SH) {
    	enum __WORDSIZE=32;
    }

    version(SH64) {
    	enum __WORDSIZE=64;
    }

    version(Alpha) {
    	enum __WORDSIZE=64;
    }


}
