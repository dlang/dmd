/**
 * D header file for GNU/Linux.
 *
 * License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Authors:   Paul O'Neil
 */
module core.sys.linux.sys.socket;

public import core.sys.posix.sys.socket;

version(linux):
extern(C):
@nogc:
nothrow:

enum {
    AF_RXRPC    = 33,
    PF_RXRPC    = AF_RXRPC,
}
