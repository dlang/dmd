/* TEST_OUTPUT:
---
getModuleClasses: tuple("test23558.C")
getModuleClasses: tuple("std.stdio.StdioException")
---
*/

// https://issues.dlang.org/show_bug.cgi?id=23558

import std.stdio;

class C { }

pragma(msg, "getModuleClasses: ", __traits(getModuleClasses));
pragma(msg, "getModuleClasses: ", __traits(getModuleClasses, std.stdio));

//pragma(msg, "getClassInfos: ", __traits(getModuleClasses, 3));
