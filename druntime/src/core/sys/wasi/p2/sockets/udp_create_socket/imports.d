/++

+/
module core.sys.wasi.p2.sockets.udp_create_socket.imports;

import core.sys.wasi.wit_common;

public import core.sys.wasi.p2.sockets.udp_create_socket.common;

static import core.sys.wasi.p2.sockets.network.imports;
static import core.sys.wasi.p2.sockets.udp.imports;

package (core.sys.wasi.p2) void __wit_bindgen_component_type_force_link() pure @nogc nothrow => imported!"core.sys.wasi.p2.cli.imports".__wit_bindgen_component_type_force_link();

/++

+/
alias Network = core.sys.wasi.p2.sockets.network.imports.Network;

/++

+/
alias UdpSocket = core.sys.wasi.p2.sockets.udp.imports.UdpSocket;

/++

+/
Result!(UdpSocket, ErrorCode) createUdpSocket(in IpAddressFamily addressFamily) @nogc nothrow {
  align(4) void[8] _retArea = void;
  __import_createUdpSocket(cast(uint)(addressFamily), _retArea.ptr);
  Result!(UdpSocket, ErrorCode) _result2 = void;
  bool _isErr2 = (cast(uint)(*(cast(ubyte*)(_retArea.ptr + 0)))) != 0;
  if (_isErr2) {

    _result2 = Result!(UdpSocket, ErrorCode).err(cast(core.sys.wasi.p2.sockets.network.imports.ErrorCode)(cast(uint)(*(cast(ubyte*)(_retArea.ptr + 4)))));
  } else {

    _result2 = Result!(UdpSocket, ErrorCode).ok(UdpSocket(*(cast(uint*)(_retArea.ptr + 4))));
  }
  auto _flush3 = _result2;
  return _flush3;
}
/// ditto
@wasmImport!("wasi:sockets/udp-create-socket@0.2.12", "create-udp-socket")
pragma(mangle, "__wit_import_wasi:sockets__udp_create_socket@0.2.12__create_udp_socket")
private extern(C) void __import_createUdpSocket(uint, void*) @nogc nothrow;
