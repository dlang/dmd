// EXTRA_FILES: imports/imp21539a.d imports/imp21539b.d

// https://issues.dlang.org/show_bug.cgi?id=21539

import imports.imp21539a;

static assert(!__traits(compiles, C.File)); // private import mixin
static assert(!__traits(compiles, C.PrivateFile)); // ditto
static assert(!__traits(compiles, C.X)); // private type

static assert(__traits(compiles, D.File)); // public import mixin
static assert(!__traits(compiles, D.PrivateFile)); // ditto but private member inside
static assert(__traits(compiles, D.X)); // public type

mixin TPriv; // insert -> 'import imports.imp21539b;'
static assert(__traits(compiles, File));
static assert(!__traits(compiles, PrivateFile));

mixin TPriv2; // test 'static assert(__traits(compiles, .File))' inside mixin

