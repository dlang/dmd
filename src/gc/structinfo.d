/**
 * Contains an array of struct infos used by the GC.
 *
 * Copyright: Copyright Digital Mars 2005 - 2013.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Orvid King
 */

/*          Copyright Digital Mars 2005 - 2013.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module gc.structinfo;


import core.stdc.string;
import core.stdc.stdlib;
import core.exception : onOutOfMemoryError;

struct GCStructInfoArray
{
    StructInfo* data = null;
    size_t length = 0;
    
    void Dtor() nothrow
    {
        if (data)
        {
            free(data);
            data = null;
            length = 0;
        }
    }
    
    invariant()
    {
    }
    
    void alloc(size_t nEntries) nothrow
    {
        this.length = nEntries;
        data = cast(typeof(data[0])*)calloc(nEntries, data[0].sizeof);
        if (!data)
            onOutOfMemoryError();
    }
}
