/**
 * Defines C data model
 *
 * Copyright: Copyright Denis Feklushkin 2024.
 * License: Distributed under the
 *      $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
 *    (See accompanying file LICENSE)
 * Authors:   Denis Feklushkin
 * Source:    $(DRUNTIMESRC core/stdc/datamodel.d)
 * Standards: ISO/IEC 9899:1999 (E)
 */

module core.stdc.datamodel;

///
enum DataModel
{
    ILP32, ///
    LP64, ///
    LLP64, ///
}

version (D_LP64)
{
    version (Cygwin)
        enum dataModel = DataModel.LP64; ///
    else version (Windows)
        enum dataModel = DataModel.LLP64; ///
    else
        enum dataModel = DataModel.LP64; ///
}
else // 32-bit pointers
{
    enum dataModel = DataModel.ILP32; ///
}

static assert(__traits(compiles, typeof(dataModel)));
