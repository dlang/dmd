// Written in the D programming language.

/**
 * Interface to C++ <exception>
 *
 * Copyright: Copyright (c) 2016 D Language Foundation
 * License:   $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   $(WEB digitalmars.com, Walter Bright)
 * Source:    $(DRUNTIMESRC core/stdcpp/_exception.d)
 */

module core.stdcpp.exception;

version (CRuntime_DigitalMars)
{
    import core.stdcpp.typeinfo;

    extern (C++, std)
    {
        alias void function() unexpected_handler;
        unexpected_handler set_unexpected(unexpected_handler f) nothrow;
        void unexpected();

        alias void function() terminate_handler;
        terminate_handler set_terminate(terminate_handler f) nothrow;
        void terminate();

        bool uncaught_exception();

        class exception
        {
            this() nothrow { }
            this(const exception) nothrow { }
            //exception operator=(const exception) nothrow { return this; }
            //virtual ~this() nothrow;
            void dtor() { }
            const(char)* what() const nothrow;
        }

        class bad_exception : exception
        {
            this() nothrow { }
            this(const bad_exception) nothrow { }
            //bad_exception operator=(const bad_exception) nothrow { return this; }
            //virtual ~this() nothrow;
            override const(char)* what() const nothrow;
        }
    }
}
else version (CRuntime_Glibc)
{
    extern (C++, std)
    {
        alias void function() unexpected_handler;
        unexpected_handler set_unexpected(unexpected_handler f) nothrow;
        void unexpected();

        alias void function() terminate_handler;
        terminate_handler set_terminate(terminate_handler f) nothrow;
        void terminate();

        void unexpected();
        pure bool uncaught_exception();

        class exception
        {
            this();
            //virtual ~this();
            void dtor1();
            void dtor2();
            const(char)* what() const;
        }

        class bad_exception : exception
        {
            this();
            //virtual ~this();
            override const(char)* what() const;
        }
    }
}
else version (CRuntime_Microsoft)
{
    extern (C++, std)
    {
        class exception
        {
            this();
            this(const exception);
            //exception operator=(const exception) { return this; }
            //virtual ~this();
            void dtor() { }
            const(char)* what() const;

          private:
            const(char)* mywhat;
            bool dofree;
        }

        class bad_exception : exception
        {
            this(const(char)* msg = "bad exception");
            //virtual ~this();
        }
    }
}
