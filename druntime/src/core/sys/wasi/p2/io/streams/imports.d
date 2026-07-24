/++

+/
module core.sys.wasi.p2.io.streams.imports;

import core.sys.wasi.wit_common;

public import core.sys.wasi.p2.io.streams.common;

static import core.sys.wasi.p2.io.error.imports;
static import core.sys.wasi.p2.io.poll.imports;

package (core.sys.wasi.p2) void __wit_bindgen_component_type_force_link() pure @nogc nothrow => imported!"core.sys.wasi.p2.cli.imports".__wit_bindgen_component_type_force_link();

/++

+/
alias Error_ = core.sys.wasi.p2.io.error.imports.Error_;

/++

+/
alias Pollable = core.sys.wasi.p2.io.poll.imports.Pollable;

/++

+/
struct StreamError {
  mixin WitVariant!(
    Error_, // lastOperationFailed
    void, // closed
  );

public:
  enum Tag : ubyte {
    /++

    +/
    lastOperationFailed,

    /++

    +/
    closed,
  }
  Tag tag() const @safe @nogc nothrow pure => _tag;

  /++

  +/
  alias lastOperationFailed = _create!(Tag.lastOperationFailed);
  /// ditto
  bool isLastOperationFailed() const => _tag == Tag.lastOperationFailed;
  ///ditto
  alias getLastOperationFailed = _get!(Tag.lastOperationFailed);

  /++

  +/
  alias closed = _create!(Tag.closed);
  /// ditto
  bool isClosed() const => _tag == Tag.closed;

  void witFree() @nogc nothrow {
    switch (_tag) with (Tag) {
      case lastOperationFailed: _get!(Tag.lastOperationFailed).witFree; break;
      default: break;
    }
  }
}

/++

+/
struct InputStream {
  @nogc nothrow:

  package(core.sys.wasi.p2) uint __handle = 0;

  package(core.sys.wasi.p2) this(uint handle) {
    __handle = handle;
  }

  @disable this();


  void drop() {
    __import_drop(__handle);
  }
  @wasmImport!("wasi:io/streams@0.2.12", "[resource-drop]input-stream")
  pragma(mangle, "__wit_import_wasi:io__streams@0.2.12__:resource_drop:input_stream")
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
    Result!(WitList!(ubyte), StreamError) read(ulong len) @nogc nothrow {
      align(size_t.sizeof) void[(3*size_t.sizeof)] _retArea = void;
      __import_read(this.__handle, len, _retArea.ptr);
      Result!(WitList!(ubyte), StreamError) _result8 = void;
      bool _isErr8 = (cast(uint)(*(cast(ubyte*)(_retArea.ptr + 0)))) != 0;
      if (_isErr8) {
        StreamError _variant5 = void;
        auto _tag5 = cast(uint)(*(cast(ubyte*)(_retArea.ptr + size_t.sizeof)));
        alias _Tag5 = StreamError.Tag;
        final switch (cast(StreamError.Tag)_tag5) {
          case _Tag5.lastOperationFailed: {
            auto _payload6 = Error_(*(cast(uint*)(_retArea.ptr + (4+1*size_t.sizeof))));
            _variant5 = StreamError.lastOperationFailed(_payload6);
            break;
          }
          case _Tag5.closed: {
            _variant5 = StreamError.closed();
            break;
          }
        }

        _result8 = Result!(WitList!(ubyte), StreamError).err(_variant5);
      } else {
        auto _ptr1 = cast(ubyte*)(*(cast(void**)(_retArea.ptr + size_t.sizeof)));
        auto _len1 = *(cast(size_t*)(_retArea.ptr + (2*size_t.sizeof)));

        _result8 = Result!(WitList!(ubyte), StreamError).ok(WitList!(ubyte)(_ptr1[0.._len1]));
      }
      auto _flush9 = _result8;
      return _flush9;
    }
    /// ditto
    @wasmImport!("wasi:io/streams@0.2.12", "[method]input-stream.read")
    pragma(mangle, "__wit_import_wasi:io__streams@0.2.12__:method:input_stream.read")
    static private extern(C) void __import_read(uint, ulong, void*) @nogc nothrow;

    /++

    +/
    Result!(WitList!(ubyte), StreamError) blockingRead(ulong len) @nogc nothrow {
      align(size_t.sizeof) void[(3*size_t.sizeof)] _retArea = void;
      __import_blockingRead(this.__handle, len, _retArea.ptr);
      Result!(WitList!(ubyte), StreamError) _result8 = void;
      bool _isErr8 = (cast(uint)(*(cast(ubyte*)(_retArea.ptr + 0)))) != 0;
      if (_isErr8) {
        StreamError _variant5 = void;
        auto _tag5 = cast(uint)(*(cast(ubyte*)(_retArea.ptr + size_t.sizeof)));
        alias _Tag5 = StreamError.Tag;
        final switch (cast(StreamError.Tag)_tag5) {
          case _Tag5.lastOperationFailed: {
            auto _payload6 = Error_(*(cast(uint*)(_retArea.ptr + (4+1*size_t.sizeof))));
            _variant5 = StreamError.lastOperationFailed(_payload6);
            break;
          }
          case _Tag5.closed: {
            _variant5 = StreamError.closed();
            break;
          }
        }

        _result8 = Result!(WitList!(ubyte), StreamError).err(_variant5);
      } else {
        auto _ptr1 = cast(ubyte*)(*(cast(void**)(_retArea.ptr + size_t.sizeof)));
        auto _len1 = *(cast(size_t*)(_retArea.ptr + (2*size_t.sizeof)));

        _result8 = Result!(WitList!(ubyte), StreamError).ok(WitList!(ubyte)(_ptr1[0.._len1]));
      }
      auto _flush9 = _result8;
      return _flush9;
    }
    /// ditto
    @wasmImport!("wasi:io/streams@0.2.12", "[method]input-stream.blocking-read")
    pragma(mangle, "__wit_import_wasi:io__streams@0.2.12__:method:input_stream.blocking_read")
    static private extern(C) void __import_blockingRead(uint, ulong, void*) @nogc nothrow;

    /++

    +/
    Result!(ulong, StreamError) skip(ulong len) @nogc nothrow {
      align(8) void[16] _retArea = void;
      __import_skip(this.__handle, len, _retArea.ptr);
      Result!(ulong, StreamError) _result7 = void;
      bool _isErr7 = (cast(uint)(*(cast(ubyte*)(_retArea.ptr + 0)))) != 0;
      if (_isErr7) {
        StreamError _variant4 = void;
        auto _tag4 = cast(uint)(*(cast(ubyte*)(_retArea.ptr + 8)));
        alias _Tag4 = StreamError.Tag;
        final switch (cast(StreamError.Tag)_tag4) {
          case _Tag4.lastOperationFailed: {
            auto _payload5 = Error_(*(cast(uint*)(_retArea.ptr + 12)));
            _variant4 = StreamError.lastOperationFailed(_payload5);
            break;
          }
          case _Tag4.closed: {
            _variant4 = StreamError.closed();
            break;
          }
        }

        _result7 = Result!(ulong, StreamError).err(_variant4);
      } else {

        _result7 = Result!(ulong, StreamError).ok(*(cast(ulong*)(_retArea.ptr + 8)));
      }
      auto _flush8 = _result7;
      return _flush8;
    }
    /// ditto
    @wasmImport!("wasi:io/streams@0.2.12", "[method]input-stream.skip")
    pragma(mangle, "__wit_import_wasi:io__streams@0.2.12__:method:input_stream.skip")
    static private extern(C) void __import_skip(uint, ulong, void*) @nogc nothrow;

    /++

    +/
    Result!(ulong, StreamError) blockingSkip(ulong len) @nogc nothrow {
      align(8) void[16] _retArea = void;
      __import_blockingSkip(this.__handle, len, _retArea.ptr);
      Result!(ulong, StreamError) _result7 = void;
      bool _isErr7 = (cast(uint)(*(cast(ubyte*)(_retArea.ptr + 0)))) != 0;
      if (_isErr7) {
        StreamError _variant4 = void;
        auto _tag4 = cast(uint)(*(cast(ubyte*)(_retArea.ptr + 8)));
        alias _Tag4 = StreamError.Tag;
        final switch (cast(StreamError.Tag)_tag4) {
          case _Tag4.lastOperationFailed: {
            auto _payload5 = Error_(*(cast(uint*)(_retArea.ptr + 12)));
            _variant4 = StreamError.lastOperationFailed(_payload5);
            break;
          }
          case _Tag4.closed: {
            _variant4 = StreamError.closed();
            break;
          }
        }

        _result7 = Result!(ulong, StreamError).err(_variant4);
      } else {

        _result7 = Result!(ulong, StreamError).ok(*(cast(ulong*)(_retArea.ptr + 8)));
      }
      auto _flush8 = _result7;
      return _flush8;
    }
    /// ditto
    @wasmImport!("wasi:io/streams@0.2.12", "[method]input-stream.blocking-skip")
    pragma(mangle, "__wit_import_wasi:io__streams@0.2.12__:method:input_stream.blocking_skip")
    static private extern(C) void __import_blockingSkip(uint, ulong, void*) @nogc nothrow;

    /++

    +/
    Pollable subscribe() @nogc nothrow {
      auto _ret = __import_subscribe(this.__handle);
      return Pollable(_ret);
    }
    /// ditto
    @wasmImport!("wasi:io/streams@0.2.12", "[method]input-stream.subscribe")
    pragma(mangle, "__wit_import_wasi:io__streams@0.2.12__:method:input_stream.subscribe")
    static private extern(C) uint __import_subscribe(uint) @nogc nothrow;
  }
}

/++

+/
struct OutputStream {
  @nogc nothrow:

  package(core.sys.wasi.p2) uint __handle = 0;

  package(core.sys.wasi.p2) this(uint handle) {
    __handle = handle;
  }

  @disable this();


  void drop() {
    __import_drop(__handle);
  }
  @wasmImport!("wasi:io/streams@0.2.12", "[resource-drop]output-stream")
  pragma(mangle, "__wit_import_wasi:io__streams@0.2.12__:resource_drop:output_stream")
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
    Result!(ulong, StreamError) checkWrite() @nogc nothrow {
      align(8) void[16] _retArea = void;
      __import_checkWrite(this.__handle, _retArea.ptr);
      Result!(ulong, StreamError) _result7 = void;
      bool _isErr7 = (cast(uint)(*(cast(ubyte*)(_retArea.ptr + 0)))) != 0;
      if (_isErr7) {
        StreamError _variant4 = void;
        auto _tag4 = cast(uint)(*(cast(ubyte*)(_retArea.ptr + 8)));
        alias _Tag4 = StreamError.Tag;
        final switch (cast(StreamError.Tag)_tag4) {
          case _Tag4.lastOperationFailed: {
            auto _payload5 = Error_(*(cast(uint*)(_retArea.ptr + 12)));
            _variant4 = StreamError.lastOperationFailed(_payload5);
            break;
          }
          case _Tag4.closed: {
            _variant4 = StreamError.closed();
            break;
          }
        }

        _result7 = Result!(ulong, StreamError).err(_variant4);
      } else {

        _result7 = Result!(ulong, StreamError).ok(*(cast(ulong*)(_retArea.ptr + 8)));
      }
      auto _flush8 = _result7;
      return _flush8;
    }
    /// ditto
    @wasmImport!("wasi:io/streams@0.2.12", "[method]output-stream.check-write")
    pragma(mangle, "__wit_import_wasi:io__streams@0.2.12__:method:output_stream.check_write")
    static private extern(C) void __import_checkWrite(uint, void*) @nogc nothrow;

    /++

    +/
    Result!(void, StreamError) write(in WitList!(ubyte) contents) @nogc nothrow {
      align(4) void[12] _retArea = void;
      __import_write(this.__handle, cast(void*)(contents.ptr), contents.length, _retArea.ptr);
      Result!(void, StreamError) _result7 = void;
      bool _isErr7 = (cast(uint)(*(cast(ubyte*)(_retArea.ptr + 0)))) != 0;
      if (_isErr7) {
        StreamError _variant4 = void;
        auto _tag4 = cast(uint)(*(cast(ubyte*)(_retArea.ptr + 4)));
        alias _Tag4 = StreamError.Tag;
        final switch (cast(StreamError.Tag)_tag4) {
          case _Tag4.lastOperationFailed: {
            auto _payload5 = Error_(*(cast(uint*)(_retArea.ptr + 8)));
            _variant4 = StreamError.lastOperationFailed(_payload5);
            break;
          }
          case _Tag4.closed: {
            _variant4 = StreamError.closed();
            break;
          }
        }

        _result7 = Result!(void, StreamError).err(_variant4);
      } else {

        _result7 = Result!(void, StreamError).ok();
      }
      auto _flush8 = _result7;
      return _flush8;
    }
    /// ditto
    @wasmImport!("wasi:io/streams@0.2.12", "[method]output-stream.write")
    pragma(mangle, "__wit_import_wasi:io__streams@0.2.12__:method:output_stream.write")
    static private extern(C) void __import_write(uint, void*, size_t, void*) @nogc nothrow;

    /++

    +/
    Result!(void, StreamError) blockingWriteAndFlush(in WitList!(ubyte) contents) @nogc nothrow {
      align(4) void[12] _retArea = void;
      __import_blockingWriteAndFlush(this.__handle, cast(void*)(contents.ptr), contents.length, _retArea.ptr);
      Result!(void, StreamError) _result7 = void;
      bool _isErr7 = (cast(uint)(*(cast(ubyte*)(_retArea.ptr + 0)))) != 0;
      if (_isErr7) {
        StreamError _variant4 = void;
        auto _tag4 = cast(uint)(*(cast(ubyte*)(_retArea.ptr + 4)));
        alias _Tag4 = StreamError.Tag;
        final switch (cast(StreamError.Tag)_tag4) {
          case _Tag4.lastOperationFailed: {
            auto _payload5 = Error_(*(cast(uint*)(_retArea.ptr + 8)));
            _variant4 = StreamError.lastOperationFailed(_payload5);
            break;
          }
          case _Tag4.closed: {
            _variant4 = StreamError.closed();
            break;
          }
        }

        _result7 = Result!(void, StreamError).err(_variant4);
      } else {

        _result7 = Result!(void, StreamError).ok();
      }
      auto _flush8 = _result7;
      return _flush8;
    }
    /// ditto
    @wasmImport!("wasi:io/streams@0.2.12", "[method]output-stream.blocking-write-and-flush")
    pragma(mangle, "__wit_import_wasi:io__streams@0.2.12__:method:output_stream.blocking_write_and_flush")
    static private extern(C) void __import_blockingWriteAndFlush(uint, void*, size_t, void*) @nogc nothrow;

    /++

    +/
    Result!(void, StreamError) flush() @nogc nothrow {
      align(4) void[12] _retArea = void;
      __import_flush(this.__handle, _retArea.ptr);
      Result!(void, StreamError) _result7 = void;
      bool _isErr7 = (cast(uint)(*(cast(ubyte*)(_retArea.ptr + 0)))) != 0;
      if (_isErr7) {
        StreamError _variant4 = void;
        auto _tag4 = cast(uint)(*(cast(ubyte*)(_retArea.ptr + 4)));
        alias _Tag4 = StreamError.Tag;
        final switch (cast(StreamError.Tag)_tag4) {
          case _Tag4.lastOperationFailed: {
            auto _payload5 = Error_(*(cast(uint*)(_retArea.ptr + 8)));
            _variant4 = StreamError.lastOperationFailed(_payload5);
            break;
          }
          case _Tag4.closed: {
            _variant4 = StreamError.closed();
            break;
          }
        }

        _result7 = Result!(void, StreamError).err(_variant4);
      } else {

        _result7 = Result!(void, StreamError).ok();
      }
      auto _flush8 = _result7;
      return _flush8;
    }
    /// ditto
    @wasmImport!("wasi:io/streams@0.2.12", "[method]output-stream.flush")
    pragma(mangle, "__wit_import_wasi:io__streams@0.2.12__:method:output_stream.flush")
    static private extern(C) void __import_flush(uint, void*) @nogc nothrow;

    /++

    +/
    Result!(void, StreamError) blockingFlush() @nogc nothrow {
      align(4) void[12] _retArea = void;
      __import_blockingFlush(this.__handle, _retArea.ptr);
      Result!(void, StreamError) _result7 = void;
      bool _isErr7 = (cast(uint)(*(cast(ubyte*)(_retArea.ptr + 0)))) != 0;
      if (_isErr7) {
        StreamError _variant4 = void;
        auto _tag4 = cast(uint)(*(cast(ubyte*)(_retArea.ptr + 4)));
        alias _Tag4 = StreamError.Tag;
        final switch (cast(StreamError.Tag)_tag4) {
          case _Tag4.lastOperationFailed: {
            auto _payload5 = Error_(*(cast(uint*)(_retArea.ptr + 8)));
            _variant4 = StreamError.lastOperationFailed(_payload5);
            break;
          }
          case _Tag4.closed: {
            _variant4 = StreamError.closed();
            break;
          }
        }

        _result7 = Result!(void, StreamError).err(_variant4);
      } else {

        _result7 = Result!(void, StreamError).ok();
      }
      auto _flush8 = _result7;
      return _flush8;
    }
    /// ditto
    @wasmImport!("wasi:io/streams@0.2.12", "[method]output-stream.blocking-flush")
    pragma(mangle, "__wit_import_wasi:io__streams@0.2.12__:method:output_stream.blocking_flush")
    static private extern(C) void __import_blockingFlush(uint, void*) @nogc nothrow;

    /++

    +/
    Pollable subscribe() @nogc nothrow {
      auto _ret = __import_subscribe(this.__handle);
      return Pollable(_ret);
    }
    /// ditto
    @wasmImport!("wasi:io/streams@0.2.12", "[method]output-stream.subscribe")
    pragma(mangle, "__wit_import_wasi:io__streams@0.2.12__:method:output_stream.subscribe")
    static private extern(C) uint __import_subscribe(uint) @nogc nothrow;

    /++

    +/
    Result!(void, StreamError) writeZeroes(ulong len) @nogc nothrow {
      align(4) void[12] _retArea = void;
      __import_writeZeroes(this.__handle, len, _retArea.ptr);
      Result!(void, StreamError) _result7 = void;
      bool _isErr7 = (cast(uint)(*(cast(ubyte*)(_retArea.ptr + 0)))) != 0;
      if (_isErr7) {
        StreamError _variant4 = void;
        auto _tag4 = cast(uint)(*(cast(ubyte*)(_retArea.ptr + 4)));
        alias _Tag4 = StreamError.Tag;
        final switch (cast(StreamError.Tag)_tag4) {
          case _Tag4.lastOperationFailed: {
            auto _payload5 = Error_(*(cast(uint*)(_retArea.ptr + 8)));
            _variant4 = StreamError.lastOperationFailed(_payload5);
            break;
          }
          case _Tag4.closed: {
            _variant4 = StreamError.closed();
            break;
          }
        }

        _result7 = Result!(void, StreamError).err(_variant4);
      } else {

        _result7 = Result!(void, StreamError).ok();
      }
      auto _flush8 = _result7;
      return _flush8;
    }
    /// ditto
    @wasmImport!("wasi:io/streams@0.2.12", "[method]output-stream.write-zeroes")
    pragma(mangle, "__wit_import_wasi:io__streams@0.2.12__:method:output_stream.write_zeroes")
    static private extern(C) void __import_writeZeroes(uint, ulong, void*) @nogc nothrow;

    /++

    +/
    Result!(void, StreamError) blockingWriteZeroesAndFlush(ulong len) @nogc nothrow {
      align(4) void[12] _retArea = void;
      __import_blockingWriteZeroesAndFlush(this.__handle, len, _retArea.ptr);
      Result!(void, StreamError) _result7 = void;
      bool _isErr7 = (cast(uint)(*(cast(ubyte*)(_retArea.ptr + 0)))) != 0;
      if (_isErr7) {
        StreamError _variant4 = void;
        auto _tag4 = cast(uint)(*(cast(ubyte*)(_retArea.ptr + 4)));
        alias _Tag4 = StreamError.Tag;
        final switch (cast(StreamError.Tag)_tag4) {
          case _Tag4.lastOperationFailed: {
            auto _payload5 = Error_(*(cast(uint*)(_retArea.ptr + 8)));
            _variant4 = StreamError.lastOperationFailed(_payload5);
            break;
          }
          case _Tag4.closed: {
            _variant4 = StreamError.closed();
            break;
          }
        }

        _result7 = Result!(void, StreamError).err(_variant4);
      } else {

        _result7 = Result!(void, StreamError).ok();
      }
      auto _flush8 = _result7;
      return _flush8;
    }
    /// ditto
    @wasmImport!("wasi:io/streams@0.2.12", "[method]output-stream.blocking-write-zeroes-and-flush")
    pragma(mangle, "__wit_import_wasi:io__streams@0.2.12__:method:output_stream.blocking_write_zeroes_and_flush")
    static private extern(C) void __import_blockingWriteZeroesAndFlush(uint, ulong, void*) @nogc nothrow;

    /++

    +/
    Result!(ulong, StreamError) splice(in InputStream.Borrow src, ulong len) @nogc nothrow {
      align(8) void[16] _retArea = void;
      __import_splice(this.__handle, src.__handle, len, _retArea.ptr);
      Result!(ulong, StreamError) _result7 = void;
      bool _isErr7 = (cast(uint)(*(cast(ubyte*)(_retArea.ptr + 0)))) != 0;
      if (_isErr7) {
        StreamError _variant4 = void;
        auto _tag4 = cast(uint)(*(cast(ubyte*)(_retArea.ptr + 8)));
        alias _Tag4 = StreamError.Tag;
        final switch (cast(StreamError.Tag)_tag4) {
          case _Tag4.lastOperationFailed: {
            auto _payload5 = Error_(*(cast(uint*)(_retArea.ptr + 12)));
            _variant4 = StreamError.lastOperationFailed(_payload5);
            break;
          }
          case _Tag4.closed: {
            _variant4 = StreamError.closed();
            break;
          }
        }

        _result7 = Result!(ulong, StreamError).err(_variant4);
      } else {

        _result7 = Result!(ulong, StreamError).ok(*(cast(ulong*)(_retArea.ptr + 8)));
      }
      auto _flush8 = _result7;
      return _flush8;
    }
    /// ditto
    @wasmImport!("wasi:io/streams@0.2.12", "[method]output-stream.splice")
    pragma(mangle, "__wit_import_wasi:io__streams@0.2.12__:method:output_stream.splice")
    static private extern(C) void __import_splice(uint, uint, ulong, void*) @nogc nothrow;

    /++

    +/
    Result!(ulong, StreamError) blockingSplice(in InputStream.Borrow src, ulong len) @nogc nothrow {
      align(8) void[16] _retArea = void;
      __import_blockingSplice(this.__handle, src.__handle, len, _retArea.ptr);
      Result!(ulong, StreamError) _result7 = void;
      bool _isErr7 = (cast(uint)(*(cast(ubyte*)(_retArea.ptr + 0)))) != 0;
      if (_isErr7) {
        StreamError _variant4 = void;
        auto _tag4 = cast(uint)(*(cast(ubyte*)(_retArea.ptr + 8)));
        alias _Tag4 = StreamError.Tag;
        final switch (cast(StreamError.Tag)_tag4) {
          case _Tag4.lastOperationFailed: {
            auto _payload5 = Error_(*(cast(uint*)(_retArea.ptr + 12)));
            _variant4 = StreamError.lastOperationFailed(_payload5);
            break;
          }
          case _Tag4.closed: {
            _variant4 = StreamError.closed();
            break;
          }
        }

        _result7 = Result!(ulong, StreamError).err(_variant4);
      } else {

        _result7 = Result!(ulong, StreamError).ok(*(cast(ulong*)(_retArea.ptr + 8)));
      }
      auto _flush8 = _result7;
      return _flush8;
    }
    /// ditto
    @wasmImport!("wasi:io/streams@0.2.12", "[method]output-stream.blocking-splice")
    pragma(mangle, "__wit_import_wasi:io__streams@0.2.12__:method:output_stream.blocking_splice")
    static private extern(C) void __import_blockingSplice(uint, uint, ulong, void*) @nogc nothrow;
  }
}
