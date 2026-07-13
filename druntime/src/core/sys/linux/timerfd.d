/**
 * Compatibility shim for $(MREF core,sys,linux,sys,timerfd).
 *
 * Deprecated: Use $(MREF core,sys,linux,sys,timerfd) instead to match the
 *             C header location `sys/timerfd.h`.
 *
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 */
deprecated("use core.sys.linux.sys.timerfd instead to match the C header sys/timerfd.h")
module core.sys.linux.timerfd;

version (linux):

public import core.sys.linux.sys.timerfd;
