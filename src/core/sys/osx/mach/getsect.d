/**
 * Copyright: Copyright Digital Mars 2010.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Jacob Carlborg
 * Version: Initial created: Mar 16, 2010
 */

/*          Copyright Digital Mars 2010.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module core.sys.osx.mach.getsect;

version (OSX):

import core.sys.osx.mach.loader;

extern (C):

section* getsectbynamefromheader (in mach_header* mhp, in char* segname, in char* sectname);
section_64* getsectbynamefromheader_64 (mach_header_64* mhp, in char* segname, in char* sectname);

