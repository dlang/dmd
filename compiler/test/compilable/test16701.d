// REQUIRED_ARGS: -Icompilable/imports

// https://issues.dlang.org/show_bug.cgi?id=16701
// On Windows, Package.d may be capitalized since the file system is not case sensitive.
version(Windows)
{
	import pkg16701;
}
