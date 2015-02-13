// This file is part of Visual D
//
// Visual D integrates the D programming language into Visual Studio
// Copyright (c) 2010-2011 by Rainer Schuetze, All Rights Reserved
//
// Distributed under the Boost Software License, Version 1.0.
// See accompanying file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt

module stdext.util;

////////////////////////////////////////////////////////////////
inout(T) static_cast(T, S = Object)(inout(S) p)
{
    if(!p)
        return null;
    if(__ctfe)
        return cast(inout(T)) p;
    assert(cast(inout(T)) p);
    void* vp = cast(void*)p;
    return cast(inout(T)) vp;
}

////////////////////////////////////////////////////////////////
bool isIn(T...)(T values)
{
    T[0] needle = values[0];
    foreach(v; values[1..$])
        if(v == needle)
            return true;
    return false;
}
