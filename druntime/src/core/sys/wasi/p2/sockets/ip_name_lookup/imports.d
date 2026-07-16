/++

+/
module core.sys.wasi.p2.sockets.ip_name_lookup.imports;

import core.sys.wasi.wit_common;

public import core.sys.wasi.p2.sockets.ip_name_lookup.common;

static import core.sys.wasi.p2.io.poll.imports;
static import core.sys.wasi.p2.sockets.network.imports;

package (core.sys.wasi.p2) void __wit_bindgen_component_type_force_link() pure @nogc nothrow => imported!"core.sys.wasi.p2.cli.imports".__wit_bindgen_component_type_force_link();

/++

+/
alias Pollable = core.sys.wasi.p2.io.poll.imports.Pollable;

/++

+/
alias Network = core.sys.wasi.p2.sockets.network.imports.Network;

/++

+/
struct ResolveAddressStream {
  @nogc nothrow:

  package(core.sys.wasi.p2) uint __handle = 0;

  package(core.sys.wasi.p2) this(uint handle) {
    __handle = handle;
  }

  @disable this();


  void drop() {
    __import_drop(__handle);
  }
  @wasmImport!("wasi:sockets/ip-name-lookup@0.2.12", "[resource-drop]resolve-address-stream")
  pragma(mangle, "__wit_import_wasi:sockets__ip_name_lookup@0.2.12__:resource_drop:resolve_address_stream")
  static private extern(C) void __import_drop(uint);

  alias witFree = drop;
  // TODO: make RAII? disable copy for the own

  Borrow borrow() => Borrow(__handle);
  alias borrow this;

  struct Borrow {
    @nogc nothrow:

    package(core.sys.wasi.p2) uint __handle = 0;

    package(core.sys.wasi.p2) this(uint handle) {
      __handle = handle;
    }

    @disable this();

    void witFree() {}
    Borrow witClone() const { return Borrow(__handle); }

    /++

    +/
    Result!(Option!(IpAddress), ErrorCode) resolveNextAddress() @nogc nothrow {
      align(2) void[22] _retArea = void;
      __import_resolveNextAddress(this.__handle, _retArea.ptr);
      Result!(Option!(IpAddress), ErrorCode) _result12 = void;
      bool _isErr12 = (cast(uint)(*(cast(ubyte*)(_retArea.ptr + 0)))) != 0;
      if (_isErr12) {

        _result12 = Result!(Option!(IpAddress), ErrorCode).err(cast(core.sys.wasi.p2.sockets.network.imports.ErrorCode)(cast(uint)(*(cast(ubyte*)(_retArea.ptr + 2)))));
      } else {
        Option!(IpAddress) _option10 = void;
        bool _isSome10 = (cast(uint)(*(cast(ubyte*)(_retArea.ptr + 2)))) != 0;
        if (_isSome10) {
          core.sys.wasi.p2.sockets.network.imports.IpAddress _variant7 = void;
          auto _tag7 = cast(uint)(*(cast(ubyte*)(_retArea.ptr + 4)));
          alias _Tag7 = core.sys.wasi.p2.sockets.network.imports.IpAddress.Tag;
          final switch (cast(core.sys.wasi.p2.sockets.network.imports.IpAddress.Tag)_tag7) {
            case _Tag7.ipv4: {
              auto _tuple4 = core.sys.wasi.p2.sockets.network.imports.Ipv4Address(
              cast(ubyte)(cast(uint)(*(cast(ubyte*)(_retArea.ptr + 6)))),
              cast(ubyte)(cast(uint)(*(cast(ubyte*)(_retArea.ptr + 7)))),
              cast(ubyte)(cast(uint)(*(cast(ubyte*)(_retArea.ptr + 8)))),
              cast(ubyte)(cast(uint)(*(cast(ubyte*)(_retArea.ptr + 9)))),
              );
              auto _payload8 = _tuple4;
              _variant7 = core.sys.wasi.p2.sockets.network.imports.IpAddress.ipv4(_payload8);
              break;
            }
            case _Tag7.ipv6: {
              auto _tuple6 = core.sys.wasi.p2.sockets.network.imports.Ipv6Address(
              cast(ushort)(cast(uint)(*(cast(ushort*)(_retArea.ptr + 6)))),
              cast(ushort)(cast(uint)(*(cast(ushort*)(_retArea.ptr + 8)))),
              cast(ushort)(cast(uint)(*(cast(ushort*)(_retArea.ptr + 10)))),
              cast(ushort)(cast(uint)(*(cast(ushort*)(_retArea.ptr + 12)))),
              cast(ushort)(cast(uint)(*(cast(ushort*)(_retArea.ptr + 14)))),
              cast(ushort)(cast(uint)(*(cast(ushort*)(_retArea.ptr + 16)))),
              cast(ushort)(cast(uint)(*(cast(ushort*)(_retArea.ptr + 18)))),
              cast(ushort)(cast(uint)(*(cast(ushort*)(_retArea.ptr + 20)))),
              );
              auto _payload9 = _tuple6;
              _variant7 = core.sys.wasi.p2.sockets.network.imports.IpAddress.ipv6(_payload9);
              break;
            }
          }

          _option10 = Option!(IpAddress).some(_variant7);
        } else {
          _option10 = Option!(IpAddress).none;
        }

        _result12 = Result!(Option!(IpAddress), ErrorCode).ok(_option10);
      }
      auto _flush13 = _result12;
      return _flush13;
    }
    /// ditto
    @wasmImport!("wasi:sockets/ip-name-lookup@0.2.12", "[method]resolve-address-stream.resolve-next-address")
    pragma(mangle, "__wit_import_wasi:sockets__ip_name_lookup@0.2.12__:method:resolve_address_stream.resolve_next_address")
    static private extern(C) void __import_resolveNextAddress(uint, void*) @nogc nothrow;

    /++

    +/
    Pollable subscribe() @nogc nothrow {
      auto _ret = __import_subscribe(this.__handle);
      return Pollable(_ret);
    }
    /// ditto
    @wasmImport!("wasi:sockets/ip-name-lookup@0.2.12", "[method]resolve-address-stream.subscribe")
    pragma(mangle, "__wit_import_wasi:sockets__ip_name_lookup@0.2.12__:method:resolve_address_stream.subscribe")
    static private extern(C) uint __import_subscribe(uint) @nogc nothrow;
  }
}

/++

+/
Result!(ResolveAddressStream, ErrorCode) resolveAddresses(in Network.Borrow network, in WitString name) @nogc nothrow {
  align(4) void[8] _retArea = void;
  __import_resolveAddresses(network.__handle, cast(void*)(name.ptr), name.length, _retArea.ptr);
  Result!(ResolveAddressStream, ErrorCode) _result2 = void;
  bool _isErr2 = (cast(uint)(*(cast(ubyte*)(_retArea.ptr + 0)))) != 0;
  if (_isErr2) {

    _result2 = Result!(ResolveAddressStream, ErrorCode).err(cast(core.sys.wasi.p2.sockets.network.imports.ErrorCode)(cast(uint)(*(cast(ubyte*)(_retArea.ptr + 4)))));
  } else {

    _result2 = Result!(ResolveAddressStream, ErrorCode).ok(ResolveAddressStream(*(cast(uint*)(_retArea.ptr + 4))));
  }
  auto _flush3 = _result2;
  return _flush3;
}
/// ditto
@wasmImport!("wasi:sockets/ip-name-lookup@0.2.12", "resolve-addresses")
pragma(mangle, "__wit_import_wasi:sockets__ip_name_lookup@0.2.12__resolve_addresses")
private extern(C) void __import_resolveAddresses(uint, void*, size_t, void*) @nogc nothrow;
