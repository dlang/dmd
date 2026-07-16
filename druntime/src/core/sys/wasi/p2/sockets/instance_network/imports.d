/++

+/
module core.sys.wasi.p2.sockets.instance_network.imports;

import core.sys.wasi.wit_common;

public import core.sys.wasi.p2.sockets.instance_network.common;

static import core.sys.wasi.p2.sockets.network.imports;

package (core.sys.wasi.p2) void __wit_bindgen_component_type_force_link() pure @nogc nothrow => imported!"core.sys.wasi.p2.cli.imports".__wit_bindgen_component_type_force_link();

/++

+/
alias Network = core.sys.wasi.p2.sockets.network.imports.Network;

/++

+/
Network instanceNetwork() @nogc nothrow {
  auto _ret = __import_instanceNetwork();
  return Network(_ret);
}
/// ditto
@wasmImport!("wasi:sockets/instance-network@0.2.12", "instance-network")
pragma(mangle, "__wit_import_wasi:sockets__instance_network@0.2.12__instance_network")
private extern(C) uint __import_instanceNetwork() @nogc nothrow;
