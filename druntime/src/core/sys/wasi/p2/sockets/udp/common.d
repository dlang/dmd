/++

+/
module core.sys.wasi.p2.sockets.udp.common;

import core.sys.wasi.wit_common;

static import core.sys.wasi.p2.io.poll.common;
static import core.sys.wasi.p2.sockets.network.common;

package (core.sys.wasi.p2) void __wit_bindgen_component_type_force_link() pure @nogc nothrow => imported!"core.sys.wasi.p2.cli.imports".__wit_bindgen_component_type_force_link();

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
struct IncomingDatagram {
  /++

  +/
  WitList!(ubyte) data;

  /++

  +/
  IpSocketAddress remoteAddress;

  void witFree() @nogc nothrow {
    data.witFree;
  }

  IncomingDatagram witClone() const @nogc nothrow {
    IncomingDatagram clone = void;
    clone.data = this.data.witClone;
    clone.remoteAddress = this.remoteAddress.witClone;
    return clone;
  }
}

/++

+/
struct OutgoingDatagram {
  /++

  +/
  WitList!(ubyte) data;

  /++

  +/
  Option!(IpSocketAddress) remoteAddress;

  void witFree() @nogc nothrow {
    data.witFree;
  }

  OutgoingDatagram witClone() const @nogc nothrow {
    OutgoingDatagram clone = void;
    clone.data = this.data.witClone;
    clone.remoteAddress = this.remoteAddress.witClone;
    return clone;
  }
}
