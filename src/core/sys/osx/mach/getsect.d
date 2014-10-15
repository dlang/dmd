/**
 * Copyright: Copyright Digital Mars 2010.
 * License:   $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   Jacob Carlborg
 * Version: Initial created: Mar 16, 2010
 */

/*          Copyright Digital Mars 2010.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module core.sys.osx.mach.getsect;

version (OSX):
extern (C):

public import core.sys.osx.mach.loader;

const(section)*    getsectbynamefromheader(in mach_header* mhp, in char* segname, in char* sectname);
const(section_64)* getsectbynamefromheader_64(in mach_header_64* mhp, in char* segname, in char* sectname);

