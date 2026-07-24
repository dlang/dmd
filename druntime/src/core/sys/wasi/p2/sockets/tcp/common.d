/++

+/
module core.sys.wasi.p2.sockets.tcp.common;

import core.sys.wasi.wit_common;

static import core.sys.wasi.p2.io.poll.common;
static import core.sys.wasi.p2.io.streams.common;
static import core.sys.wasi.p2.clocks.monotonic_clock.common;
static import core.sys.wasi.p2.sockets.network.common;

package (core.sys.wasi.p2) void __wit_bindgen_component_type_force_link() pure @nogc nothrow => imported!"core.sys.wasi.p2.cli.imports".__wit_bindgen_component_type_force_link();

/++

+/
alias Duration = core.sys.wasi.p2.clocks.monotonic_clock.common.Duration;

/++

+/
alias ErrorCode = core.sys.wasi.p2.sockets.network.common.ErrorCode;

/++

+/
alias IpSocketAddress = core.sys.wasi.p2.sockets.network.common.IpSocketAddress;

/++

+/
alias IpAddressFamily = core.sys.wasi.p2.sockets.network.common.IpAddressFamily;

/++

+/
enum ShutdownType : ubyte {
  /++

  +/
  receive,

  /++

  +/
  send,

  /++

  +/
  both,
}
