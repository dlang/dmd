/++

+/
module core.sys.wasi.p2.sockets.udp.imports;

import core.sys.wasi.wit_common;

public import core.sys.wasi.p2.sockets.udp.common;

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
struct UdpSocket {
  @nogc nothrow:

  package(core.sys.wasi.p2) uint __handle = 0;

  package(core.sys.wasi.p2) this(uint handle) {
    __handle = handle;
  }

  @disable this();


  void drop() {
    __import_drop(__handle);
  }
  @wasmImport!("wasi:sockets/udp@0.2.12", "[resource-drop]udp-socket")
  pragma(mangle, "__wit_import_wasi:sockets__udp@0.2.12__:resource_drop:udp_socket")
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
    Result!(void, ErrorCode) startBind(in Network.Borrow network, in IpSocketAddress localAddress) @nogc nothrow {
      align(1) void[2] _retArea = void;
      uint _variantPart4 = void;
      uint _variantPart5 = void;
      uint _variantPart6 = void;
      uint _variantPart7 = void;
      uint _variantPart8 = void;
      uint _variantPart9 = void;
      uint _variantPart10 = void;
      uint _variantPart11 = void;
      uint _variantPart12 = void;
      uint _variantPart13 = void;
      uint _variantPart14 = void;
      uint _variantPart15 = void;
      alias _Tag16 = core.sys.wasi.p2.sockets.network.imports.IpSocketAddress.Tag;
      final switch (localAddress.tag) {
        case _Tag16.ipv4: {
          const ref core.sys.wasi.p2.sockets.network.imports.Ipv4SocketAddress _payload1 = localAddress.getIpv4();
          _variantPart4 = 0;
          _variantPart5 = cast(uint)(_payload1.port);
          _variantPart6 = cast(uint)(_payload1.address[0]);
          _variantPart7 = cast(uint)(_payload1.address[1]);
          _variantPart8 = cast(uint)(_payload1.address[2]);
          _variantPart9 = cast(uint)(_payload1.address[3]);
          _variantPart10 = 0;
          _variantPart11 = 0;
          _variantPart12 = 0;
          _variantPart13 = 0;
          _variantPart14 = 0;
          _variantPart15 = 0;
          break;
        }
        case _Tag16.ipv6: {
          const ref core.sys.wasi.p2.sockets.network.imports.Ipv6SocketAddress _payload3 = localAddress.getIpv6();
          _variantPart4 = 1;
          _variantPart5 = cast(uint)(_payload3.port);
          _variantPart6 = _payload3.flowInfo;
          _variantPart7 = cast(uint)(_payload3.address[0]);
          _variantPart8 = cast(uint)(_payload3.address[1]);
          _variantPart9 = cast(uint)(_payload3.address[2]);
          _variantPart10 = cast(uint)(_payload3.address[3]);
          _variantPart11 = cast(uint)(_payload3.address[4]);
          _variantPart12 = cast(uint)(_payload3.address[5]);
          _variantPart13 = cast(uint)(_payload3.address[6]);
          _variantPart14 = cast(uint)(_payload3.address[7]);
          _variantPart15 = _payload3.scopeId;
          break;
        }
      }
      __import_startBind(this.__handle, network.__handle, _variantPart4, _variantPart5, _variantPart6, _variantPart7, _variantPart8, _variantPart9, _variantPart10, _variantPart11, _variantPart12, _variantPart13, _variantPart14, _variantPart15, _retArea.ptr);
      Result!(void, ErrorCode) _result19 = void;
      bool _isErr19 = (cast(uint)(*(cast(ubyte*)(_retArea.ptr + 0)))) != 0;
      if (_isErr19) {

        _result19 = Result!(void, ErrorCode).err(cast(core.sys.wasi.p2.sockets.network.imports.ErrorCode)(cast(uint)(*(cast(ubyte*)(_retArea.ptr + 1)))));
      } else {

        _result19 = Result!(void, ErrorCode).ok();
      }
      auto _flush20 = _result19;
      return _flush20;
    }
    /// ditto
    @wasmImport!("wasi:sockets/udp@0.2.12", "[method]udp-socket.start-bind")
    pragma(mangle, "__wit_import_wasi:sockets__udp@0.2.12__:method:udp_socket.start_bind")
    static private extern(C) void __import_startBind(uint, uint, uint, uint, uint, uint, uint, uint, uint, uint, uint, uint, uint, uint, void*) @nogc nothrow;

    /++

    +/
    Result!(void, ErrorCode) finishBind() @nogc nothrow {
      align(1) void[2] _retArea = void;
      __import_finishBind(this.__handle, _retArea.ptr);
      Result!(void, ErrorCode) _result2 = void;
      bool _isErr2 = (cast(uint)(*(cast(ubyte*)(_retArea.ptr + 0)))) != 0;
      if (_isErr2) {

        _result2 = Result!(void, ErrorCode).err(cast(core.sys.wasi.p2.sockets.network.imports.ErrorCode)(cast(uint)(*(cast(ubyte*)(_retArea.ptr + 1)))));
      } else {

        _result2 = Result!(void, ErrorCode).ok();
      }
      auto _flush3 = _result2;
      return _flush3;
    }
    /// ditto
    @wasmImport!("wasi:sockets/udp@0.2.12", "[method]udp-socket.finish-bind")
    pragma(mangle, "__wit_import_wasi:sockets__udp@0.2.12__:method:udp_socket.finish_bind")
    static private extern(C) void __import_finishBind(uint, void*) @nogc nothrow;

    /++

    +/
    Result!(Tuple!(IncomingDatagramStream, OutgoingDatagramStream), ErrorCode) stream(in Option!(IpSocketAddress) remoteAddress) @nogc nothrow {
      align(4) void[12] _retArea = void;
      uint _option21 = void;
      uint _option22 = void;
      uint _option23 = void;
      uint _option24 = void;
      uint _option25 = void;
      uint _option26 = void;
      uint _option27 = void;
      uint _option28 = void;
      uint _option29 = void;
      uint _option30 = void;
      uint _option31 = void;
      uint _option32 = void;
      uint _option33 = void;
      if (remoteAddress.isSome) {
        ref _payload3 = remoteAddress.unwrap();
        uint _variantPart8 = void;
        uint _variantPart9 = void;
        uint _variantPart10 = void;
        uint _variantPart11 = void;
        uint _variantPart12 = void;
        uint _variantPart13 = void;
        uint _variantPart14 = void;
        uint _variantPart15 = void;
        uint _variantPart16 = void;
        uint _variantPart17 = void;
        uint _variantPart18 = void;
        uint _variantPart19 = void;
        alias _Tag20 = core.sys.wasi.p2.sockets.network.imports.IpSocketAddress.Tag;
        final switch (_payload3.tag) {
          case _Tag20.ipv4: {
            const ref core.sys.wasi.p2.sockets.network.imports.Ipv4SocketAddress _payload5 = _payload3.getIpv4();
            _variantPart8 = 0;
            _variantPart9 = cast(uint)(_payload5.port);
            _variantPart10 = cast(uint)(_payload5.address[0]);
            _variantPart11 = cast(uint)(_payload5.address[1]);
            _variantPart12 = cast(uint)(_payload5.address[2]);
            _variantPart13 = cast(uint)(_payload5.address[3]);
            _variantPart14 = 0;
            _variantPart15 = 0;
            _variantPart16 = 0;
            _variantPart17 = 0;
            _variantPart18 = 0;
            _variantPart19 = 0;
            break;
          }
          case _Tag20.ipv6: {
            const ref core.sys.wasi.p2.sockets.network.imports.Ipv6SocketAddress _payload7 = _payload3.getIpv6();
            _variantPart8 = 1;
            _variantPart9 = cast(uint)(_payload7.port);
            _variantPart10 = _payload7.flowInfo;
            _variantPart11 = cast(uint)(_payload7.address[0]);
            _variantPart12 = cast(uint)(_payload7.address[1]);
            _variantPart13 = cast(uint)(_payload7.address[2]);
            _variantPart14 = cast(uint)(_payload7.address[3]);
            _variantPart15 = cast(uint)(_payload7.address[4]);
            _variantPart16 = cast(uint)(_payload7.address[5]);
            _variantPart17 = cast(uint)(_payload7.address[6]);
            _variantPart18 = cast(uint)(_payload7.address[7]);
            _variantPart19 = _payload7.scopeId;
            break;
          }
        }
        _option21 = 1;
        _option22 = _variantPart8;
        _option23 = _variantPart9;
        _option24 = _variantPart10;
        _option25 = _variantPart11;
        _option26 = _variantPart12;
        _option27 = _variantPart13;
        _option28 = _variantPart14;
        _option29 = _variantPart15;
        _option30 = _variantPart16;
        _option31 = _variantPart17;
        _option32 = _variantPart18;
        _option33 = _variantPart19;
      } else {
        _option21 = 0;
        _option22 = 0;
        _option23 = 0;
        _option24 = 0;
        _option25 = 0;
        _option26 = 0;
        _option27 = 0;
        _option28 = 0;
        _option29 = 0;
        _option30 = 0;
        _option31 = 0;
        _option32 = 0;
        _option33 = 0;
      }
      __import_stream(this.__handle, _option21, _option22, _option23, _option24, _option25, _option26, _option27, _option28, _option29, _option30, _option31, _option32, _option33, _retArea.ptr);
      Result!(Tuple!(IncomingDatagramStream, OutgoingDatagramStream), ErrorCode) _result37 = void;
      bool _isErr37 = (cast(uint)(*(cast(ubyte*)(_retArea.ptr + 0)))) != 0;
      if (_isErr37) {

        _result37 = Result!(Tuple!(IncomingDatagramStream, OutgoingDatagramStream), ErrorCode).err(cast(core.sys.wasi.p2.sockets.network.imports.ErrorCode)(cast(uint)(*(cast(ubyte*)(_retArea.ptr + 4)))));
      } else {
        auto _tuple35 = Tuple!(IncomingDatagramStream, OutgoingDatagramStream)(
        IncomingDatagramStream(*(cast(uint*)(_retArea.ptr + 4))),
        OutgoingDatagramStream(*(cast(uint*)(_retArea.ptr + 8))),
        );

        _result37 = Result!(Tuple!(IncomingDatagramStream, OutgoingDatagramStream), ErrorCode).ok(_tuple35);
      }
      auto _flush38 = _result37;
      return _flush38;
    }
    /// ditto
    @wasmImport!("wasi:sockets/udp@0.2.12", "[method]udp-socket.stream")
    pragma(mangle, "__wit_import_wasi:sockets__udp@0.2.12__:method:udp_socket.stream")
    static private extern(C) void __import_stream(uint, uint, uint, uint, uint, uint, uint, uint, uint, uint, uint, uint, uint, uint, void*) @nogc nothrow;

    /++

    +/
    Result!(IpSocketAddress, ErrorCode) localAddress() @nogc nothrow {
      align(4) void[36] _retArea = void;
      __import_localAddress(this.__handle, _retArea.ptr);
      Result!(IpSocketAddress, ErrorCode) _result11 = void;
      bool _isErr11 = (cast(uint)(*(cast(ubyte*)(_retArea.ptr + 0)))) != 0;
      if (_isErr11) {

        _result11 = Result!(IpSocketAddress, ErrorCode).err(cast(core.sys.wasi.p2.sockets.network.imports.ErrorCode)(cast(uint)(*(cast(ubyte*)(_retArea.ptr + 4)))));
      } else {
        core.sys.wasi.p2.sockets.network.imports.IpSocketAddress _variant7 = void;
        auto _tag7 = cast(uint)(*(cast(ubyte*)(_retArea.ptr + 4)));
        alias _Tag7 = core.sys.wasi.p2.sockets.network.imports.IpSocketAddress.Tag;
        final switch (cast(core.sys.wasi.p2.sockets.network.imports.IpSocketAddress.Tag)_tag7) {
          case _Tag7.ipv4: {
            auto _tuple2 = core.sys.wasi.p2.sockets.network.imports.Ipv4Address(
            cast(ubyte)(cast(uint)(*(cast(ubyte*)(_retArea.ptr + 10)))),
            cast(ubyte)(cast(uint)(*(cast(ubyte*)(_retArea.ptr + 11)))),
            cast(ubyte)(cast(uint)(*(cast(ubyte*)(_retArea.ptr + 12)))),
            cast(ubyte)(cast(uint)(*(cast(ubyte*)(_retArea.ptr + 13)))),
            );
            core.sys.wasi.p2.sockets.network.imports.Ipv4SocketAddress _record3 = {
              port: cast(ushort)(cast(uint)(*(cast(ushort*)(_retArea.ptr + 8)))),
              address: _tuple2,
            };
            auto _payload8 = _record3;
            _variant7 = core.sys.wasi.p2.sockets.network.imports.IpSocketAddress.ipv4(_payload8);
            break;
          }
          case _Tag7.ipv6: {
            auto _tuple5 = core.sys.wasi.p2.sockets.network.imports.Ipv6Address(
            cast(ushort)(cast(uint)(*(cast(ushort*)(_retArea.ptr + 16)))),
            cast(ushort)(cast(uint)(*(cast(ushort*)(_retArea.ptr + 18)))),
            cast(ushort)(cast(uint)(*(cast(ushort*)(_retArea.ptr + 20)))),
            cast(ushort)(cast(uint)(*(cast(ushort*)(_retArea.ptr + 22)))),
            cast(ushort)(cast(uint)(*(cast(ushort*)(_retArea.ptr + 24)))),
            cast(ushort)(cast(uint)(*(cast(ushort*)(_retArea.ptr + 26)))),
            cast(ushort)(cast(uint)(*(cast(ushort*)(_retArea.ptr + 28)))),
            cast(ushort)(cast(uint)(*(cast(ushort*)(_retArea.ptr + 30)))),
            );
            core.sys.wasi.p2.sockets.network.imports.Ipv6SocketAddress _record6 = {
              port: cast(ushort)(cast(uint)(*(cast(ushort*)(_retArea.ptr + 8)))),
              flowInfo: *(cast(uint*)(_retArea.ptr + 12)),
              address: _tuple5,
              scopeId: *(cast(uint*)(_retArea.ptr + 32)),
            };
            auto _payload9 = _record6;
            _variant7 = core.sys.wasi.p2.sockets.network.imports.IpSocketAddress.ipv6(_payload9);
            break;
          }
        }

        _result11 = Result!(IpSocketAddress, ErrorCode).ok(_variant7);
      }
      auto _flush12 = _result11;
      return _flush12;
    }
    /// ditto
    @wasmImport!("wasi:sockets/udp@0.2.12", "[method]udp-socket.local-address")
    pragma(mangle, "__wit_import_wasi:sockets__udp@0.2.12__:method:udp_socket.local_address")
    static private extern(C) void __import_localAddress(uint, void*) @nogc nothrow;

    /++

    +/
    Result!(IpSocketAddress, ErrorCode) remoteAddress() @nogc nothrow {
      align(4) void[36] _retArea = void;
      __import_remoteAddress(this.__handle, _retArea.ptr);
      Result!(IpSocketAddress, ErrorCode) _result11 = void;
      bool _isErr11 = (cast(uint)(*(cast(ubyte*)(_retArea.ptr + 0)))) != 0;
      if (_isErr11) {

        _result11 = Result!(IpSocketAddress, ErrorCode).err(cast(core.sys.wasi.p2.sockets.network.imports.ErrorCode)(cast(uint)(*(cast(ubyte*)(_retArea.ptr + 4)))));
      } else {
        core.sys.wasi.p2.sockets.network.imports.IpSocketAddress _variant7 = void;
        auto _tag7 = cast(uint)(*(cast(ubyte*)(_retArea.ptr + 4)));
        alias _Tag7 = core.sys.wasi.p2.sockets.network.imports.IpSocketAddress.Tag;
        final switch (cast(core.sys.wasi.p2.sockets.network.imports.IpSocketAddress.Tag)_tag7) {
          case _Tag7.ipv4: {
            auto _tuple2 = core.sys.wasi.p2.sockets.network.imports.Ipv4Address(
            cast(ubyte)(cast(uint)(*(cast(ubyte*)(_retArea.ptr + 10)))),
            cast(ubyte)(cast(uint)(*(cast(ubyte*)(_retArea.ptr + 11)))),
            cast(ubyte)(cast(uint)(*(cast(ubyte*)(_retArea.ptr + 12)))),
            cast(ubyte)(cast(uint)(*(cast(ubyte*)(_retArea.ptr + 13)))),
            );
            core.sys.wasi.p2.sockets.network.imports.Ipv4SocketAddress _record3 = {
              port: cast(ushort)(cast(uint)(*(cast(ushort*)(_retArea.ptr + 8)))),
              address: _tuple2,
            };
            auto _payload8 = _record3;
            _variant7 = core.sys.wasi.p2.sockets.network.imports.IpSocketAddress.ipv4(_payload8);
            break;
          }
          case _Tag7.ipv6: {
            auto _tuple5 = core.sys.wasi.p2.sockets.network.imports.Ipv6Address(
            cast(ushort)(cast(uint)(*(cast(ushort*)(_retArea.ptr + 16)))),
            cast(ushort)(cast(uint)(*(cast(ushort*)(_retArea.ptr + 18)))),
            cast(ushort)(cast(uint)(*(cast(ushort*)(_retArea.ptr + 20)))),
            cast(ushort)(cast(uint)(*(cast(ushort*)(_retArea.ptr + 22)))),
            cast(ushort)(cast(uint)(*(cast(ushort*)(_retArea.ptr + 24)))),
            cast(ushort)(cast(uint)(*(cast(ushort*)(_retArea.ptr + 26)))),
            cast(ushort)(cast(uint)(*(cast(ushort*)(_retArea.ptr + 28)))),
            cast(ushort)(cast(uint)(*(cast(ushort*)(_retArea.ptr + 30)))),
            );
            core.sys.wasi.p2.sockets.network.imports.Ipv6SocketAddress _record6 = {
              port: cast(ushort)(cast(uint)(*(cast(ushort*)(_retArea.ptr + 8)))),
              flowInfo: *(cast(uint*)(_retArea.ptr + 12)),
              address: _tuple5,
              scopeId: *(cast(uint*)(_retArea.ptr + 32)),
            };
            auto _payload9 = _record6;
            _variant7 = core.sys.wasi.p2.sockets.network.imports.IpSocketAddress.ipv6(_payload9);
            break;
          }
        }

        _result11 = Result!(IpSocketAddress, ErrorCode).ok(_variant7);
      }
      auto _flush12 = _result11;
      return _flush12;
    }
    /// ditto
    @wasmImport!("wasi:sockets/udp@0.2.12", "[method]udp-socket.remote-address")
    pragma(mangle, "__wit_import_wasi:sockets__udp@0.2.12__:method:udp_socket.remote_address")
    static private extern(C) void __import_remoteAddress(uint, void*) @nogc nothrow;

    /++

    +/
    IpAddressFamily addressFamily() @nogc nothrow {
      auto _ret = __import_addressFamily(this.__handle);
      return cast(core.sys.wasi.p2.sockets.network.imports.IpAddressFamily)(_ret);
    }
    /// ditto
    @wasmImport!("wasi:sockets/udp@0.2.12", "[method]udp-socket.address-family")
    pragma(mangle, "__wit_import_wasi:sockets__udp@0.2.12__:method:udp_socket.address_family")
    static private extern(C) uint __import_addressFamily(uint) @nogc nothrow;

    /++

    +/
    Result!(ubyte, ErrorCode) unicastHopLimit() @nogc nothrow {
      align(1) void[2] _retArea = void;
      __import_unicastHopLimit(this.__handle, _retArea.ptr);
      Result!(ubyte, ErrorCode) _result2 = void;
      bool _isErr2 = (cast(uint)(*(cast(ubyte*)(_retArea.ptr + 0)))) != 0;
      if (_isErr2) {

        _result2 = Result!(ubyte, ErrorCode).err(cast(core.sys.wasi.p2.sockets.network.imports.ErrorCode)(cast(uint)(*(cast(ubyte*)(_retArea.ptr + 1)))));
      } else {

        _result2 = Result!(ubyte, ErrorCode).ok(cast(ubyte)(cast(uint)(*(cast(ubyte*)(_retArea.ptr + 1)))));
      }
      auto _flush3 = _result2;
      return _flush3;
    }
    /// ditto
    @wasmImport!("wasi:sockets/udp@0.2.12", "[method]udp-socket.unicast-hop-limit")
    pragma(mangle, "__wit_import_wasi:sockets__udp@0.2.12__:method:udp_socket.unicast_hop_limit")
    static private extern(C) void __import_unicastHopLimit(uint, void*) @nogc nothrow;

    /++

    +/
    Result!(void, ErrorCode) setUnicastHopLimit(ubyte value) @nogc nothrow {
      align(1) void[2] _retArea = void;
      __import_setUnicastHopLimit(this.__handle, cast(uint)(value), _retArea.ptr);
      Result!(void, ErrorCode) _result2 = void;
      bool _isErr2 = (cast(uint)(*(cast(ubyte*)(_retArea.ptr + 0)))) != 0;
      if (_isErr2) {

        _result2 = Result!(void, ErrorCode).err(cast(core.sys.wasi.p2.sockets.network.imports.ErrorCode)(cast(uint)(*(cast(ubyte*)(_retArea.ptr + 1)))));
      } else {

        _result2 = Result!(void, ErrorCode).ok();
      }
      auto _flush3 = _result2;
      return _flush3;
    }
    /// ditto
    @wasmImport!("wasi:sockets/udp@0.2.12", "[method]udp-socket.set-unicast-hop-limit")
    pragma(mangle, "__wit_import_wasi:sockets__udp@0.2.12__:method:udp_socket.set_unicast_hop_limit")
    static private extern(C) void __import_setUnicastHopLimit(uint, uint, void*) @nogc nothrow;

    /++

    +/
    Result!(ulong, ErrorCode) receiveBufferSize() @nogc nothrow {
      align(8) void[16] _retArea = void;
      __import_receiveBufferSize(this.__handle, _retArea.ptr);
      Result!(ulong, ErrorCode) _result2 = void;
      bool _isErr2 = (cast(uint)(*(cast(ubyte*)(_retArea.ptr + 0)))) != 0;
      if (_isErr2) {

        _result2 = Result!(ulong, ErrorCode).err(cast(core.sys.wasi.p2.sockets.network.imports.ErrorCode)(cast(uint)(*(cast(ubyte*)(_retArea.ptr + 8)))));
      } else {

        _result2 = Result!(ulong, ErrorCode).ok(*(cast(ulong*)(_retArea.ptr + 8)));
      }
      auto _flush3 = _result2;
      return _flush3;
    }
    /// ditto
    @wasmImport!("wasi:sockets/udp@0.2.12", "[method]udp-socket.receive-buffer-size")
    pragma(mangle, "__wit_import_wasi:sockets__udp@0.2.12__:method:udp_socket.receive_buffer_size")
    static private extern(C) void __import_receiveBufferSize(uint, void*) @nogc nothrow;

    /++

    +/
    Result!(void, ErrorCode) setReceiveBufferSize(ulong value) @nogc nothrow {
      align(1) void[2] _retArea = void;
      __import_setReceiveBufferSize(this.__handle, value, _retArea.ptr);
      Result!(void, ErrorCode) _result2 = void;
      bool _isErr2 = (cast(uint)(*(cast(ubyte*)(_retArea.ptr + 0)))) != 0;
      if (_isErr2) {

        _result2 = Result!(void, ErrorCode).err(cast(core.sys.wasi.p2.sockets.network.imports.ErrorCode)(cast(uint)(*(cast(ubyte*)(_retArea.ptr + 1)))));
      } else {

        _result2 = Result!(void, ErrorCode).ok();
      }
      auto _flush3 = _result2;
      return _flush3;
    }
    /// ditto
    @wasmImport!("wasi:sockets/udp@0.2.12", "[method]udp-socket.set-receive-buffer-size")
    pragma(mangle, "__wit_import_wasi:sockets__udp@0.2.12__:method:udp_socket.set_receive_buffer_size")
    static private extern(C) void __import_setReceiveBufferSize(uint, ulong, void*) @nogc nothrow;

    /++

    +/
    Result!(ulong, ErrorCode) sendBufferSize() @nogc nothrow {
      align(8) void[16] _retArea = void;
      __import_sendBufferSize(this.__handle, _retArea.ptr);
      Result!(ulong, ErrorCode) _result2 = void;
      bool _isErr2 = (cast(uint)(*(cast(ubyte*)(_retArea.ptr + 0)))) != 0;
      if (_isErr2) {

        _result2 = Result!(ulong, ErrorCode).err(cast(core.sys.wasi.p2.sockets.network.imports.ErrorCode)(cast(uint)(*(cast(ubyte*)(_retArea.ptr + 8)))));
      } else {

        _result2 = Result!(ulong, ErrorCode).ok(*(cast(ulong*)(_retArea.ptr + 8)));
      }
      auto _flush3 = _result2;
      return _flush3;
    }
    /// ditto
    @wasmImport!("wasi:sockets/udp@0.2.12", "[method]udp-socket.send-buffer-size")
    pragma(mangle, "__wit_import_wasi:sockets__udp@0.2.12__:method:udp_socket.send_buffer_size")
    static private extern(C) void __import_sendBufferSize(uint, void*) @nogc nothrow;

    /++

    +/
    Result!(void, ErrorCode) setSendBufferSize(ulong value) @nogc nothrow {
      align(1) void[2] _retArea = void;
      __import_setSendBufferSize(this.__handle, value, _retArea.ptr);
      Result!(void, ErrorCode) _result2 = void;
      bool _isErr2 = (cast(uint)(*(cast(ubyte*)(_retArea.ptr + 0)))) != 0;
      if (_isErr2) {

        _result2 = Result!(void, ErrorCode).err(cast(core.sys.wasi.p2.sockets.network.imports.ErrorCode)(cast(uint)(*(cast(ubyte*)(_retArea.ptr + 1)))));
      } else {

        _result2 = Result!(void, ErrorCode).ok();
      }
      auto _flush3 = _result2;
      return _flush3;
    }
    /// ditto
    @wasmImport!("wasi:sockets/udp@0.2.12", "[method]udp-socket.set-send-buffer-size")
    pragma(mangle, "__wit_import_wasi:sockets__udp@0.2.12__:method:udp_socket.set_send_buffer_size")
    static private extern(C) void __import_setSendBufferSize(uint, ulong, void*) @nogc nothrow;

    /++

    +/
    Pollable subscribe() @nogc nothrow {
      auto _ret = __import_subscribe(this.__handle);
      return Pollable(_ret);
    }
    /// ditto
    @wasmImport!("wasi:sockets/udp@0.2.12", "[method]udp-socket.subscribe")
    pragma(mangle, "__wit_import_wasi:sockets__udp@0.2.12__:method:udp_socket.subscribe")
    static private extern(C) uint __import_subscribe(uint) @nogc nothrow;
  }
}

/++

+/
struct IncomingDatagramStream {
  @nogc nothrow:

  package(core.sys.wasi.p2) uint __handle = 0;

  package(core.sys.wasi.p2) this(uint handle) {
    __handle = handle;
  }

  @disable this();


  void drop() {
    __import_drop(__handle);
  }
  @wasmImport!("wasi:sockets/udp@0.2.12", "[resource-drop]incoming-datagram-stream")
  pragma(mangle, "__wit_import_wasi:sockets__udp@0.2.12__:resource_drop:incoming_datagram_stream")
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
    Result!(WitList!(IncomingDatagram), ErrorCode) receive(ulong maxResults) @nogc nothrow {
      align(size_t.sizeof) void[(3*size_t.sizeof)] _retArea = void;
      __import_receive(this.__handle, maxResults, _retArea.ptr);
      Result!(WitList!(IncomingDatagram), ErrorCode) _result15 = void;
      bool _isErr15 = (cast(uint)(*(cast(ubyte*)(_retArea.ptr + 0)))) != 0;
      if (_isErr15) {

        _result15 = Result!(WitList!(IncomingDatagram), ErrorCode).err(cast(core.sys.wasi.p2.sockets.network.imports.ErrorCode)(cast(uint)(*(cast(ubyte*)(_retArea.ptr + size_t.sizeof)))));
      } else {
        auto _listSrcPtr13 = *(cast(void**)(_retArea.ptr + size_t.sizeof));
        auto _listLen13 = *(cast(size_t*)(_retArea.ptr + (2*size_t.sizeof)));
        auto _list13 = core.sys.wasi.wit_common.mallocSlice!(IncomingDatagram)(_listLen13);
        foreach (_elem1_idx, ref _elem1; _list13) {
          const auto _base1 = _listSrcPtr13 + _elem1_idx * (32+2*size_t.sizeof);
          auto _ptr2 = cast(ubyte*)(*(cast(void**)(_base1 + 0)));
          auto _len2 = *(cast(size_t*)(_base1 + size_t.sizeof));
          core.sys.wasi.p2.sockets.network.imports.IpSocketAddress _variant9 = void;
          auto _tag9 = cast(uint)(*(cast(ubyte*)(_base1 + (2*size_t.sizeof))));
          alias _Tag9 = core.sys.wasi.p2.sockets.network.imports.IpSocketAddress.Tag;
          final switch (cast(core.sys.wasi.p2.sockets.network.imports.IpSocketAddress.Tag)_tag9) {
            case _Tag9.ipv4: {
              auto _tuple4 = core.sys.wasi.p2.sockets.network.imports.Ipv4Address(
              cast(ubyte)(cast(uint)(*(cast(ubyte*)(_base1 + (6+2*size_t.sizeof))))),
              cast(ubyte)(cast(uint)(*(cast(ubyte*)(_base1 + (7+2*size_t.sizeof))))),
              cast(ubyte)(cast(uint)(*(cast(ubyte*)(_base1 + (8+2*size_t.sizeof))))),
              cast(ubyte)(cast(uint)(*(cast(ubyte*)(_base1 + (9+2*size_t.sizeof))))),
              );
              core.sys.wasi.p2.sockets.network.imports.Ipv4SocketAddress _record5 = {
                port: cast(ushort)(cast(uint)(*(cast(ushort*)(_base1 + (4+2*size_t.sizeof))))),
                address: _tuple4,
              };
              auto _payload10 = _record5;
              _variant9 = core.sys.wasi.p2.sockets.network.imports.IpSocketAddress.ipv4(_payload10);
              break;
            }
            case _Tag9.ipv6: {
              auto _tuple7 = core.sys.wasi.p2.sockets.network.imports.Ipv6Address(
              cast(ushort)(cast(uint)(*(cast(ushort*)(_base1 + (12+2*size_t.sizeof))))),
              cast(ushort)(cast(uint)(*(cast(ushort*)(_base1 + (14+2*size_t.sizeof))))),
              cast(ushort)(cast(uint)(*(cast(ushort*)(_base1 + (16+2*size_t.sizeof))))),
              cast(ushort)(cast(uint)(*(cast(ushort*)(_base1 + (18+2*size_t.sizeof))))),
              cast(ushort)(cast(uint)(*(cast(ushort*)(_base1 + (20+2*size_t.sizeof))))),
              cast(ushort)(cast(uint)(*(cast(ushort*)(_base1 + (22+2*size_t.sizeof))))),
              cast(ushort)(cast(uint)(*(cast(ushort*)(_base1 + (24+2*size_t.sizeof))))),
              cast(ushort)(cast(uint)(*(cast(ushort*)(_base1 + (26+2*size_t.sizeof))))),
              );
              core.sys.wasi.p2.sockets.network.imports.Ipv6SocketAddress _record8 = {
                port: cast(ushort)(cast(uint)(*(cast(ushort*)(_base1 + (4+2*size_t.sizeof))))),
                flowInfo: *(cast(uint*)(_base1 + (8+2*size_t.sizeof))),
                address: _tuple7,
                scopeId: *(cast(uint*)(_base1 + (28+2*size_t.sizeof))),
              };
              auto _payload11 = _record8;
              _variant9 = core.sys.wasi.p2.sockets.network.imports.IpSocketAddress.ipv6(_payload11);
              break;
            }
          }
          IncomingDatagram _record12 = {
            data: WitList!(ubyte)(_ptr2[0.._len2]),
            remoteAddress: _variant9,
          };
          _elem1 = _record12;
        }

        _result15 = Result!(WitList!(IncomingDatagram), ErrorCode).ok(WitList!(IncomingDatagram)(_list13));
      }
      auto _flush16 = _result15;
      return _flush16;
    }
    /// ditto
    @wasmImport!("wasi:sockets/udp@0.2.12", "[method]incoming-datagram-stream.receive")
    pragma(mangle, "__wit_import_wasi:sockets__udp@0.2.12__:method:incoming_datagram_stream.receive")
    static private extern(C) void __import_receive(uint, ulong, void*) @nogc nothrow;

    /++

    +/
    Pollable subscribe() @nogc nothrow {
      auto _ret = __import_subscribe(this.__handle);
      return Pollable(_ret);
    }
    /// ditto
    @wasmImport!("wasi:sockets/udp@0.2.12", "[method]incoming-datagram-stream.subscribe")
    pragma(mangle, "__wit_import_wasi:sockets__udp@0.2.12__:method:incoming_datagram_stream.subscribe")
    static private extern(C) uint __import_subscribe(uint) @nogc nothrow;
  }
}

/++

+/
struct OutgoingDatagramStream {
  @nogc nothrow:

  package(core.sys.wasi.p2) uint __handle = 0;

  package(core.sys.wasi.p2) this(uint handle) {
    __handle = handle;
  }

  @disable this();


  void drop() {
    __import_drop(__handle);
  }
  @wasmImport!("wasi:sockets/udp@0.2.12", "[resource-drop]outgoing-datagram-stream")
  pragma(mangle, "__wit_import_wasi:sockets__udp@0.2.12__:resource_drop:outgoing_datagram_stream")
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
    Result!(ulong, ErrorCode) checkSend() @nogc nothrow {
      align(8) void[16] _retArea = void;
      __import_checkSend(this.__handle, _retArea.ptr);
      Result!(ulong, ErrorCode) _result2 = void;
      bool _isErr2 = (cast(uint)(*(cast(ubyte*)(_retArea.ptr + 0)))) != 0;
      if (_isErr2) {

        _result2 = Result!(ulong, ErrorCode).err(cast(core.sys.wasi.p2.sockets.network.imports.ErrorCode)(cast(uint)(*(cast(ubyte*)(_retArea.ptr + 8)))));
      } else {

        _result2 = Result!(ulong, ErrorCode).ok(*(cast(ulong*)(_retArea.ptr + 8)));
      }
      auto _flush3 = _result2;
      return _flush3;
    }
    /// ditto
    @wasmImport!("wasi:sockets/udp@0.2.12", "[method]outgoing-datagram-stream.check-send")
    pragma(mangle, "__wit_import_wasi:sockets__udp@0.2.12__:method:outgoing_datagram_stream.check_send")
    static private extern(C) void __import_checkSend(uint, void*) @nogc nothrow;

    /++

    +/
    Result!(ulong, ErrorCode) send(in WitList!(OutgoingDatagram) datagrams) @nogc nothrow {
      align(8) void[16] _retArea = void;
      auto _listSrc10 = datagrams;
      auto _list10 = core.sys.wasi.wit_common.malloc(_listSrc10.length * ((32+3*size_t.sizeof)));
      scope(exit) { core.sys.wasi.wit_common.free(_list10); }
      foreach (_elem0_idx, const ref _elem0; _listSrc10) {
        auto _base0 = _list10 + _elem0_idx * ((32+3*size_t.sizeof));
        *cast(size_t*)(_base0 + size_t.sizeof) = cast(size_t)(_elem0.data.length);
        *cast(void**)(_base0 + 0) = cast(void*)(cast(void*)(_elem0.data.ptr));
        if (_elem0.remoteAddress.isSome) {
          ref _payload4 = _elem0.remoteAddress.unwrap();
          *cast(ubyte*)(_base0 + (2*size_t.sizeof)) = cast(ubyte)(1);
          alias _Tag9 = core.sys.wasi.p2.sockets.network.imports.IpSocketAddress.Tag;
          final switch (_payload4.tag) {
            case _Tag9.ipv4: {
              const ref core.sys.wasi.p2.sockets.network.imports.Ipv4SocketAddress _payload6 = _payload4.getIpv4();
              *cast(ubyte*)(_base0 + (4+2*size_t.sizeof)) = cast(ubyte)(0);
              *cast(ushort*)(_base0 + (8+2*size_t.sizeof)) = cast(ushort)(cast(uint)(_payload6.port));
              *cast(ubyte*)(_base0 + (10+2*size_t.sizeof)) = cast(ubyte)(cast(uint)(_payload6.address[0]));
              *cast(ubyte*)(_base0 + (11+2*size_t.sizeof)) = cast(ubyte)(cast(uint)(_payload6.address[1]));
              *cast(ubyte*)(_base0 + (12+2*size_t.sizeof)) = cast(ubyte)(cast(uint)(_payload6.address[2]));
              *cast(ubyte*)(_base0 + (13+2*size_t.sizeof)) = cast(ubyte)(cast(uint)(_payload6.address[3]));
              break;
            }
            case _Tag9.ipv6: {
              const ref core.sys.wasi.p2.sockets.network.imports.Ipv6SocketAddress _payload8 = _payload4.getIpv6();
              *cast(ubyte*)(_base0 + (4+2*size_t.sizeof)) = cast(ubyte)(1);
              *cast(ushort*)(_base0 + (8+2*size_t.sizeof)) = cast(ushort)(cast(uint)(_payload8.port));
              *cast(uint*)(_base0 + (12+2*size_t.sizeof)) = cast(uint)(_payload8.flowInfo);
              *cast(ushort*)(_base0 + (16+2*size_t.sizeof)) = cast(ushort)(cast(uint)(_payload8.address[0]));
              *cast(ushort*)(_base0 + (18+2*size_t.sizeof)) = cast(ushort)(cast(uint)(_payload8.address[1]));
              *cast(ushort*)(_base0 + (20+2*size_t.sizeof)) = cast(ushort)(cast(uint)(_payload8.address[2]));
              *cast(ushort*)(_base0 + (22+2*size_t.sizeof)) = cast(ushort)(cast(uint)(_payload8.address[3]));
              *cast(ushort*)(_base0 + (24+2*size_t.sizeof)) = cast(ushort)(cast(uint)(_payload8.address[4]));
              *cast(ushort*)(_base0 + (26+2*size_t.sizeof)) = cast(ushort)(cast(uint)(_payload8.address[5]));
              *cast(ushort*)(_base0 + (28+2*size_t.sizeof)) = cast(ushort)(cast(uint)(_payload8.address[6]));
              *cast(ushort*)(_base0 + (30+2*size_t.sizeof)) = cast(ushort)(cast(uint)(_payload8.address[7]));
              *cast(uint*)(_base0 + (32+2*size_t.sizeof)) = cast(uint)(_payload8.scopeId);
              break;
            }
          }
        } else {
          *cast(ubyte*)(_base0 + (2*size_t.sizeof)) = cast(ubyte)(0);
        }

      }
      __import_send(this.__handle, _list10, datagrams.length, _retArea.ptr);
      Result!(ulong, ErrorCode) _result13 = void;
      bool _isErr13 = (cast(uint)(*(cast(ubyte*)(_retArea.ptr + 0)))) != 0;
      if (_isErr13) {

        _result13 = Result!(ulong, ErrorCode).err(cast(core.sys.wasi.p2.sockets.network.imports.ErrorCode)(cast(uint)(*(cast(ubyte*)(_retArea.ptr + 8)))));
      } else {

        _result13 = Result!(ulong, ErrorCode).ok(*(cast(ulong*)(_retArea.ptr + 8)));
      }
      auto _flush14 = _result13;
      return _flush14;
    }
    /// ditto
    @wasmImport!("wasi:sockets/udp@0.2.12", "[method]outgoing-datagram-stream.send")
    pragma(mangle, "__wit_import_wasi:sockets__udp@0.2.12__:method:outgoing_datagram_stream.send")
    static private extern(C) void __import_send(uint, void*, size_t, void*) @nogc nothrow;

    /++

    +/
    Pollable subscribe() @nogc nothrow {
      auto _ret = __import_subscribe(this.__handle);
      return Pollable(_ret);
    }
    /// ditto
    @wasmImport!("wasi:sockets/udp@0.2.12", "[method]outgoing-datagram-stream.subscribe")
    pragma(mangle, "__wit_import_wasi:sockets__udp@0.2.12__:method:outgoing_datagram_stream.subscribe")
    static private extern(C) uint __import_subscribe(uint) @nogc nothrow;
  }
}
