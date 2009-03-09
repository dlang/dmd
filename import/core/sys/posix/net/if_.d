/**
 * D header file for POSIX.
 *
 * Copyright: Public Domain
 * License:   Public Domain
 * Authors:   Sean Kelly
 * Standards: The Open Group Base Specifications Issue 6, IEEE Std 1003.1, 2004 Edition
 */
module core.sys.posix.net.if_;

private import core.sys.posix.config;

extern (C):

//
// Required
//
/*
struct if_nameindex // renamed to if_nameindex_t
{
    uint    if_index;
    char*   if_name;
}

IF_NAMESIZE

uint            if_nametoindex(in char*);
char*           if_indextoname(uint, char*);
if_nameindex_t* if_nameindex();
void            if_freenameindex(if_nameindex_t*);
*/

version( linux )
{
    struct if_nameindex_t
    {
        uint    if_index;
        char*   if_name;
    }

    enum IF_NAMESIZE = 16;

    uint            if_nametoindex(in char*);
    char*           if_indextoname(uint, char*);
    if_nameindex_t* if_nameindex();
    void            if_freenameindex(if_nameindex_t*);
}
else version( OSX )
{
    struct if_nameindex_t
    {
        uint    if_index;
        char*   if_name;
    }

    enum IF_NAMESIZE = 16;

    uint            if_nametoindex(in char*);
    char*           if_indextoname(uint, char*);
    if_nameindex_t* if_nameindex();
    void            if_freenameindex(if_nameindex_t*);
}
else version( freebsd )
{
    struct if_nameindex_t
    {
        uint    if_index;
        char*   if_name;
    }

    enum IF_NAMESIZE = 16;

    uint            if_nametoindex(in char*);
    char*           if_indextoname(uint, char*);
    if_nameindex_t* if_nameindex();
    void            if_freenameindex(if_nameindex_t*);
}
