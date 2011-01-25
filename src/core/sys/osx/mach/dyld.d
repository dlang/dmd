/**
 * Copyright: Copyright Digital Mars 2010.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Jacob Carlborg
 * Version: Initial created: Feb 20, 2010
 */

/*          Copyright Digital Mars 2010.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module core.sys.osx.mach.dyld;

version (OSX):

import core.sys.osx.mach.loader;

extern (C):

uint _dyld_image_count ();
mach_header* _dyld_get_image_header (uint image_index);


