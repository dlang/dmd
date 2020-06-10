/*
REQUIRED_ARGS: -version=tralala
EXTRA_FILES: imports/imp20915.d
*/
module issue20915;

import imp = imports.imp20915;

version = custom;
static assert (is(custom  == version));
static assert (is(tralala == version));
static assert (is(Windows == version) || is(Posix == version));
static assert (!is(XOS    == version));
static assert (is(mixin(__traits(allMembers, imp)[1]) == version));
