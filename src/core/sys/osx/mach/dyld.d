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

public import core.stdc.stdint; // for intptr_t
public import core.sys.osx.mach.loader;

extern (C):

uint         _dyld_image_count();
const(char)* _dyld_get_image_name(uint image_index);
mach_header* _dyld_get_image_header(uint image_index);
void         _dyld_register_func_for_add_image(void function(in mach_header* mh, intptr_t vmaddr_slide));
void         _dyld_register_func_for_remove_image(void function(in mach_header* mh, intptr_t vmaddr_slide));


