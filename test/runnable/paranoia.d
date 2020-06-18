/*
EXTRA_SOURCES: extra-files/paranoia.d
PERMUTE_ARGS:

ARG_SETS: -version=Single
ARG_SETS: -version=Double

ARG_SETS(win32mscoff windows64): -version=Extended ../src/dmd/root/longdouble.d
ARG_SETS(win32mscoff windows64): -version=ExtendedSoft ../src/dmd/root/longdouble.d

ARG_SETS(linux osx win32): -version=Extended
*/

module test.runnable.paranoia;
