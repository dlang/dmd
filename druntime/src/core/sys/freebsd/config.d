/**
 * D header file for FreeBSD
 *
 * Authors: Iain Buclaw
 */
module core.sys.freebsd.config;

version (FreeBSD):

public import core.sys.posix.config;

// https://svnweb.freebsd.org/base/head/sys/sys/param.h?view=markup
// __FreeBSD_version numbers are documented in the Porter's Handbook.
// NOTE: When adding newer versions of FreeBSD, verify all current versioned
// bindings are still compatible with the release.

enum __FreeBSD_version = __traits(getTargetInfo, "FreeBSDVersion");

// First version of FreeBSD to support 64-bit stat buffer.
enum INO64_FIRST = 1200000;
