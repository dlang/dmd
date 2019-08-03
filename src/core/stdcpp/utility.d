/**
 * D header file for interaction with Microsoft C++ <utility>
 *
 * Copyright: Copyright (c) 2018 D Language Foundation
 * License: Distributed under the
 *      $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
 *    (See accompanying file LICENSE)
 * Authors:   Manu Evans
 * Source:    $(DRUNTIMESRC core/stdcpp/utility.d)
 */

module core.stdcpp.utility;

import core.stdcpp.xutility : StdNamespace;

extern(C++, (StdNamespace)):
@nogc:

/**
* D language counterpart to C++ std::pair.
*
* C++ reference: $(LINK2 https://en.cppreference.com/w/cpp/utility/pair)
*/
struct pair(T1, T2)
{
    ///
    alias first_type = T1;
    ///
    alias second_type = T2;

    ///
    T1 first;
    ///
    T2 second;
}
