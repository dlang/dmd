/++

+/
module core.sys.wasi.p2.sockets.tcp_create_socket.common;

import core.sys.wasi.wit_common;

static import core.sys.wasi.p2.sockets.network.common;
static import core.sys.wasi.p2.sockets.tcp.common;

package (core.sys.wasi.p2) void __wit_bindgen_component_type_force_link() pure @nogc nothrow => imported!"core.sys.wasi.p2.cli.imports".__wit_bindgen_component_type_force_link();

/++

+/
alias ErrorCode = core.sys.wasi.p2.sockets.network.common.ErrorCode;

/++

+/
alias IpAddressFamily = core.sys.wasi.p2.sockets.network.common.IpAddressFamily;
