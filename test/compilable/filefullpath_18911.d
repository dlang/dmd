// REQUIRED_ARGS: -Icompilable/imports -c -o-

import a18911;

enum THIS_FILE = __FILE_FULL_PATH__;
enum suffix_this = "filefullpath_18911.d";

static assert(THIS_FILE[0..$-suffix_this.length] == A_FILE[0..$-suffix_a.length]);
