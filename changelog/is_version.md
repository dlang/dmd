The `is` expression allows to test if an identifier is a `version`

The result obtained when performing `__traits(allMembers)` on a module
includes the identifiers of the versions defined programmaticaly
but there was not way to identify them as actual versions.

This is now possible using a new variant of the `is` expression.

---
module m;
version = custom;
// "custom" can be included in the list return for __traits(allMembers, m)
static assert (is(custom == version));
// versions passed in the command line and reserved versions are also supported
static assert (is(Windows == version) || is(Posix == version));
// invalid versions dont produce errors
static assert (!is(XOS == version));
---
