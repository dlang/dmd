/++

+/
module core.sys.wasi.p2.filesystem.types.imports;

import core.sys.wasi.wit_common;

public import core.sys.wasi.p2.filesystem.types.common;

static import core.sys.wasi.p2.io.streams.imports;
static import core.sys.wasi.p2.clocks.wall_clock.imports;

package (core.sys.wasi.p2) void __wit_bindgen_component_type_force_link() pure @nogc nothrow => imported!"core.sys.wasi.p2.cli.imports".__wit_bindgen_component_type_force_link();

/++

+/
alias InputStream = core.sys.wasi.p2.io.streams.imports.InputStream;

/++

+/
alias OutputStream = core.sys.wasi.p2.io.streams.imports.OutputStream;

/++

+/
alias Error_ = core.sys.wasi.p2.io.streams.imports.Error_;

/++

+/
struct Descriptor {
  @nogc nothrow:

  package(core.sys.wasi.p2) uint __handle = 0;

  package(core.sys.wasi.p2) this(uint handle) {
    __handle = handle;
  }

  @disable this();


  void drop() {
    __import_drop(__handle);
  }
  @wasmImport!("wasi:filesystem/types@0.2.12", "[resource-drop]descriptor")
  pragma(mangle, "__wit_import_wasi:filesystem__types@0.2.12__:resource_drop:descriptor")
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
    Result!(InputStream, ErrorCode) readViaStream(in Filesize offset) @nogc nothrow {
      align(4) void[8] _retArea = void;
      __import_readViaStream(this.__handle, offset, _retArea.ptr);
      Result!(InputStream, ErrorCode) _result2 = void;
      bool _isErr2 = (cast(uint)(*(cast(ubyte*)(_retArea.ptr + 0)))) != 0;
      if (_isErr2) {

        _result2 = Result!(InputStream, ErrorCode).err(cast(ErrorCode)(cast(uint)(*(cast(ubyte*)(_retArea.ptr + 4)))));
      } else {

        _result2 = Result!(InputStream, ErrorCode).ok(InputStream(*(cast(uint*)(_retArea.ptr + 4))));
      }
      auto _flush3 = _result2;
      return _flush3;
    }
    /// ditto
    @wasmImport!("wasi:filesystem/types@0.2.12", "[method]descriptor.read-via-stream")
    pragma(mangle, "__wit_import_wasi:filesystem__types@0.2.12__:method:descriptor.read_via_stream")
    static private extern(C) void __import_readViaStream(uint, ulong, void*) @nogc nothrow;

    /++

    +/
    Result!(OutputStream, ErrorCode) writeViaStream(in Filesize offset) @nogc nothrow {
      align(4) void[8] _retArea = void;
      __import_writeViaStream(this.__handle, offset, _retArea.ptr);
      Result!(OutputStream, ErrorCode) _result2 = void;
      bool _isErr2 = (cast(uint)(*(cast(ubyte*)(_retArea.ptr + 0)))) != 0;
      if (_isErr2) {

        _result2 = Result!(OutputStream, ErrorCode).err(cast(ErrorCode)(cast(uint)(*(cast(ubyte*)(_retArea.ptr + 4)))));
      } else {

        _result2 = Result!(OutputStream, ErrorCode).ok(OutputStream(*(cast(uint*)(_retArea.ptr + 4))));
      }
      auto _flush3 = _result2;
      return _flush3;
    }
    /// ditto
    @wasmImport!("wasi:filesystem/types@0.2.12", "[method]descriptor.write-via-stream")
    pragma(mangle, "__wit_import_wasi:filesystem__types@0.2.12__:method:descriptor.write_via_stream")
    static private extern(C) void __import_writeViaStream(uint, ulong, void*) @nogc nothrow;

    /++

    +/
    Result!(OutputStream, ErrorCode) appendViaStream() @nogc nothrow {
      align(4) void[8] _retArea = void;
      __import_appendViaStream(this.__handle, _retArea.ptr);
      Result!(OutputStream, ErrorCode) _result2 = void;
      bool _isErr2 = (cast(uint)(*(cast(ubyte*)(_retArea.ptr + 0)))) != 0;
      if (_isErr2) {

        _result2 = Result!(OutputStream, ErrorCode).err(cast(ErrorCode)(cast(uint)(*(cast(ubyte*)(_retArea.ptr + 4)))));
      } else {

        _result2 = Result!(OutputStream, ErrorCode).ok(OutputStream(*(cast(uint*)(_retArea.ptr + 4))));
      }
      auto _flush3 = _result2;
      return _flush3;
    }
    /// ditto
    @wasmImport!("wasi:filesystem/types@0.2.12", "[method]descriptor.append-via-stream")
    pragma(mangle, "__wit_import_wasi:filesystem__types@0.2.12__:method:descriptor.append_via_stream")
    static private extern(C) void __import_appendViaStream(uint, void*) @nogc nothrow;

    /++

    +/
    Result!(void, ErrorCode) advise(in Filesize offset, in Filesize length, in Advice advice) @nogc nothrow {
      align(1) void[2] _retArea = void;
      __import_advise(this.__handle, offset, length, cast(uint)(advice), _retArea.ptr);
      Result!(void, ErrorCode) _result2 = void;
      bool _isErr2 = (cast(uint)(*(cast(ubyte*)(_retArea.ptr + 0)))) != 0;
      if (_isErr2) {

        _result2 = Result!(void, ErrorCode).err(cast(ErrorCode)(cast(uint)(*(cast(ubyte*)(_retArea.ptr + 1)))));
      } else {

        _result2 = Result!(void, ErrorCode).ok();
      }
      auto _flush3 = _result2;
      return _flush3;
    }
    /// ditto
    @wasmImport!("wasi:filesystem/types@0.2.12", "[method]descriptor.advise")
    pragma(mangle, "__wit_import_wasi:filesystem__types@0.2.12__:method:descriptor.advise")
    static private extern(C) void __import_advise(uint, ulong, ulong, uint, void*) @nogc nothrow;

    /++

    +/
    Result!(void, ErrorCode) syncData() @nogc nothrow {
      align(1) void[2] _retArea = void;
      __import_syncData(this.__handle, _retArea.ptr);
      Result!(void, ErrorCode) _result2 = void;
      bool _isErr2 = (cast(uint)(*(cast(ubyte*)(_retArea.ptr + 0)))) != 0;
      if (_isErr2) {

        _result2 = Result!(void, ErrorCode).err(cast(ErrorCode)(cast(uint)(*(cast(ubyte*)(_retArea.ptr + 1)))));
      } else {

        _result2 = Result!(void, ErrorCode).ok();
      }
      auto _flush3 = _result2;
      return _flush3;
    }
    /// ditto
    @wasmImport!("wasi:filesystem/types@0.2.12", "[method]descriptor.sync-data")
    pragma(mangle, "__wit_import_wasi:filesystem__types@0.2.12__:method:descriptor.sync_data")
    static private extern(C) void __import_syncData(uint, void*) @nogc nothrow;

    /++

    +/
    Result!(DescriptorFlags, ErrorCode) getFlags() @nogc nothrow {
      align(1) void[2] _retArea = void;
      __import_getFlags(this.__handle, _retArea.ptr);
      Result!(DescriptorFlags, ErrorCode) _result2 = void;
      bool _isErr2 = (cast(uint)(*(cast(ubyte*)(_retArea.ptr + 0)))) != 0;
      if (_isErr2) {

        _result2 = Result!(DescriptorFlags, ErrorCode).err(cast(ErrorCode)(cast(uint)(*(cast(ubyte*)(_retArea.ptr + 1)))));
      } else {

        _result2 = Result!(DescriptorFlags, ErrorCode).ok(DescriptorFlags(cast(ubyte)(cast(uint)(*(cast(ubyte*)(_retArea.ptr + 1))))));
      }
      auto _flush3 = _result2;
      return _flush3;
    }
    /// ditto
    @wasmImport!("wasi:filesystem/types@0.2.12", "[method]descriptor.get-flags")
    pragma(mangle, "__wit_import_wasi:filesystem__types@0.2.12__:method:descriptor.get_flags")
    static private extern(C) void __import_getFlags(uint, void*) @nogc nothrow;

    /++

    +/
    Result!(DescriptorType, ErrorCode) getType() @nogc nothrow {
      align(1) void[2] _retArea = void;
      __import_getType(this.__handle, _retArea.ptr);
      Result!(DescriptorType, ErrorCode) _result2 = void;
      bool _isErr2 = (cast(uint)(*(cast(ubyte*)(_retArea.ptr + 0)))) != 0;
      if (_isErr2) {

        _result2 = Result!(DescriptorType, ErrorCode).err(cast(ErrorCode)(cast(uint)(*(cast(ubyte*)(_retArea.ptr + 1)))));
      } else {

        _result2 = Result!(DescriptorType, ErrorCode).ok(cast(DescriptorType)(cast(uint)(*(cast(ubyte*)(_retArea.ptr + 1)))));
      }
      auto _flush3 = _result2;
      return _flush3;
    }
    /// ditto
    @wasmImport!("wasi:filesystem/types@0.2.12", "[method]descriptor.get-type")
    pragma(mangle, "__wit_import_wasi:filesystem__types@0.2.12__:method:descriptor.get_type")
    static private extern(C) void __import_getType(uint, void*) @nogc nothrow;

    /++

    +/
    Result!(void, ErrorCode) setSize(in Filesize size) @nogc nothrow {
      align(1) void[2] _retArea = void;
      __import_setSize(this.__handle, size, _retArea.ptr);
      Result!(void, ErrorCode) _result2 = void;
      bool _isErr2 = (cast(uint)(*(cast(ubyte*)(_retArea.ptr + 0)))) != 0;
      if (_isErr2) {

        _result2 = Result!(void, ErrorCode).err(cast(ErrorCode)(cast(uint)(*(cast(ubyte*)(_retArea.ptr + 1)))));
      } else {

        _result2 = Result!(void, ErrorCode).ok();
      }
      auto _flush3 = _result2;
      return _flush3;
    }
    /// ditto
    @wasmImport!("wasi:filesystem/types@0.2.12", "[method]descriptor.set-size")
    pragma(mangle, "__wit_import_wasi:filesystem__types@0.2.12__:method:descriptor.set_size")
    static private extern(C) void __import_setSize(uint, ulong, void*) @nogc nothrow;

    /++

    +/
    Result!(void, ErrorCode) setTimes(in NewTimestamp dataAccessTimestamp, in NewTimestamp dataModificationTimestamp) @nogc nothrow {
      align(1) void[2] _retArea = void;
      uint _variantPart6 = void;
      ulong _variantPart7 = void;
      uint _variantPart8 = void;
      alias _Tag9 = NewTimestamp.Tag;
      final switch (dataAccessTimestamp.tag) {
        case _Tag9.noChange: {
          _variantPart6 = 0;
          _variantPart7 = 0;
          _variantPart8 = 0;
          break;
        }
        case _Tag9.now: {
          _variantPart6 = 1;
          _variantPart7 = 0;
          _variantPart8 = 0;
          break;
        }
        case _Tag9.timestamp: {
          const ref Datetime _payload5 = dataAccessTimestamp.getTimestamp();
          _variantPart6 = 2;
          _variantPart7 = _payload5.seconds;
          _variantPart8 = _payload5.nanoseconds;
          break;
        }
      }
      uint _variantPart16 = void;
      ulong _variantPart17 = void;
      uint _variantPart18 = void;
      alias _Tag19 = NewTimestamp.Tag;
      final switch (dataModificationTimestamp.tag) {
        case _Tag19.noChange: {
          _variantPart16 = 0;
          _variantPart17 = 0;
          _variantPart18 = 0;
          break;
        }
        case _Tag19.now: {
          _variantPart16 = 1;
          _variantPart17 = 0;
          _variantPart18 = 0;
          break;
        }
        case _Tag19.timestamp: {
          const ref Datetime _payload15 = dataModificationTimestamp.getTimestamp();
          _variantPart16 = 2;
          _variantPart17 = _payload15.seconds;
          _variantPart18 = _payload15.nanoseconds;
          break;
        }
      }
      __import_setTimes(this.__handle, _variantPart6, _variantPart7, _variantPart8, _variantPart16, _variantPart17, _variantPart18, _retArea.ptr);
      Result!(void, ErrorCode) _result22 = void;
      bool _isErr22 = (cast(uint)(*(cast(ubyte*)(_retArea.ptr + 0)))) != 0;
      if (_isErr22) {

        _result22 = Result!(void, ErrorCode).err(cast(ErrorCode)(cast(uint)(*(cast(ubyte*)(_retArea.ptr + 1)))));
      } else {

        _result22 = Result!(void, ErrorCode).ok();
      }
      auto _flush23 = _result22;
      return _flush23;
    }
    /// ditto
    @wasmImport!("wasi:filesystem/types@0.2.12", "[method]descriptor.set-times")
    pragma(mangle, "__wit_import_wasi:filesystem__types@0.2.12__:method:descriptor.set_times")
    static private extern(C) void __import_setTimes(uint, uint, ulong, uint, uint, ulong, uint, void*) @nogc nothrow;

    /++

    +/
    Result!(Tuple!(WitList!(ubyte), bool), ErrorCode) read(in Filesize length, in Filesize offset) @nogc nothrow {
      align(size_t.sizeof) void[(4*size_t.sizeof)] _retArea = void;
      __import_read(this.__handle, length, offset, _retArea.ptr);
      Result!(Tuple!(WitList!(ubyte), bool), ErrorCode) _result4 = void;
      bool _isErr4 = (cast(uint)(*(cast(ubyte*)(_retArea.ptr + 0)))) != 0;
      if (_isErr4) {

        _result4 = Result!(Tuple!(WitList!(ubyte), bool), ErrorCode).err(cast(ErrorCode)(cast(uint)(*(cast(ubyte*)(_retArea.ptr + size_t.sizeof)))));
      } else {
        auto _ptr1 = cast(ubyte*)(*(cast(void**)(_retArea.ptr + size_t.sizeof)));
        auto _len1 = *(cast(size_t*)(_retArea.ptr + (2*size_t.sizeof)));
        auto _tuple2 = Tuple!(WitList!(ubyte), bool)(
        WitList!(ubyte)(_ptr1[0.._len1]),
        (cast(uint)(*(cast(ubyte*)(_retArea.ptr + (3*size_t.sizeof))))) != 0,
        );

        _result4 = Result!(Tuple!(WitList!(ubyte), bool), ErrorCode).ok(_tuple2);
      }
      auto _flush5 = _result4;
      return _flush5;
    }
    /// ditto
    @wasmImport!("wasi:filesystem/types@0.2.12", "[method]descriptor.read")
    pragma(mangle, "__wit_import_wasi:filesystem__types@0.2.12__:method:descriptor.read")
    static private extern(C) void __import_read(uint, ulong, ulong, void*) @nogc nothrow;

    /++

    +/
    Result!(Filesize, ErrorCode) write(in WitList!(ubyte) buffer, in Filesize offset) @nogc nothrow {
      align(8) void[16] _retArea = void;
      __import_write(this.__handle, cast(void*)(buffer.ptr), buffer.length, offset, _retArea.ptr);
      Result!(Filesize, ErrorCode) _result2 = void;
      bool _isErr2 = (cast(uint)(*(cast(ubyte*)(_retArea.ptr + 0)))) != 0;
      if (_isErr2) {

        _result2 = Result!(Filesize, ErrorCode).err(cast(ErrorCode)(cast(uint)(*(cast(ubyte*)(_retArea.ptr + 8)))));
      } else {

        _result2 = Result!(Filesize, ErrorCode).ok(*(cast(ulong*)(_retArea.ptr + 8)));
      }
      auto _flush3 = _result2;
      return _flush3;
    }
    /// ditto
    @wasmImport!("wasi:filesystem/types@0.2.12", "[method]descriptor.write")
    pragma(mangle, "__wit_import_wasi:filesystem__types@0.2.12__:method:descriptor.write")
    static private extern(C) void __import_write(uint, void*, size_t, ulong, void*) @nogc nothrow;

    /++

    +/
    Result!(DirectoryEntryStream, ErrorCode) readDirectory() @nogc nothrow {
      align(4) void[8] _retArea = void;
      __import_readDirectory(this.__handle, _retArea.ptr);
      Result!(DirectoryEntryStream, ErrorCode) _result2 = void;
      bool _isErr2 = (cast(uint)(*(cast(ubyte*)(_retArea.ptr + 0)))) != 0;
      if (_isErr2) {

        _result2 = Result!(DirectoryEntryStream, ErrorCode).err(cast(ErrorCode)(cast(uint)(*(cast(ubyte*)(_retArea.ptr + 4)))));
      } else {

        _result2 = Result!(DirectoryEntryStream, ErrorCode).ok(DirectoryEntryStream(*(cast(uint*)(_retArea.ptr + 4))));
      }
      auto _flush3 = _result2;
      return _flush3;
    }
    /// ditto
    @wasmImport!("wasi:filesystem/types@0.2.12", "[method]descriptor.read-directory")
    pragma(mangle, "__wit_import_wasi:filesystem__types@0.2.12__:method:descriptor.read_directory")
    static private extern(C) void __import_readDirectory(uint, void*) @nogc nothrow;

    /++

    +/
    Result!(void, ErrorCode) sync() @nogc nothrow {
      align(1) void[2] _retArea = void;
      __import_sync(this.__handle, _retArea.ptr);
      Result!(void, ErrorCode) _result2 = void;
      bool _isErr2 = (cast(uint)(*(cast(ubyte*)(_retArea.ptr + 0)))) != 0;
      if (_isErr2) {

        _result2 = Result!(void, ErrorCode).err(cast(ErrorCode)(cast(uint)(*(cast(ubyte*)(_retArea.ptr + 1)))));
      } else {

        _result2 = Result!(void, ErrorCode).ok();
      }
      auto _flush3 = _result2;
      return _flush3;
    }
    /// ditto
    @wasmImport!("wasi:filesystem/types@0.2.12", "[method]descriptor.sync")
    pragma(mangle, "__wit_import_wasi:filesystem__types@0.2.12__:method:descriptor.sync")
    static private extern(C) void __import_sync(uint, void*) @nogc nothrow;

    /++

    +/
    Result!(void, ErrorCode) createDirectoryAt(in WitString path) @nogc nothrow {
      align(1) void[2] _retArea = void;
      __import_createDirectoryAt(this.__handle, cast(void*)(path.ptr), path.length, _retArea.ptr);
      Result!(void, ErrorCode) _result2 = void;
      bool _isErr2 = (cast(uint)(*(cast(ubyte*)(_retArea.ptr + 0)))) != 0;
      if (_isErr2) {

        _result2 = Result!(void, ErrorCode).err(cast(ErrorCode)(cast(uint)(*(cast(ubyte*)(_retArea.ptr + 1)))));
      } else {

        _result2 = Result!(void, ErrorCode).ok();
      }
      auto _flush3 = _result2;
      return _flush3;
    }
    /// ditto
    @wasmImport!("wasi:filesystem/types@0.2.12", "[method]descriptor.create-directory-at")
    pragma(mangle, "__wit_import_wasi:filesystem__types@0.2.12__:method:descriptor.create_directory_at")
    static private extern(C) void __import_createDirectoryAt(uint, void*, size_t, void*) @nogc nothrow;

    /++

    +/
    Result!(DescriptorStat, ErrorCode) stat() @nogc nothrow {
      align(8) void[104] _retArea = void;
      __import_stat(this.__handle, _retArea.ptr);
      Result!(DescriptorStat, ErrorCode) _result15 = void;
      bool _isErr15 = (cast(uint)(*(cast(ubyte*)(_retArea.ptr + 0)))) != 0;
      if (_isErr15) {

        _result15 = Result!(DescriptorStat, ErrorCode).err(cast(ErrorCode)(cast(uint)(*(cast(ubyte*)(_retArea.ptr + 8)))));
      } else {
        Option!(Datetime) _option4 = void;
        bool _isSome4 = (cast(uint)(*(cast(ubyte*)(_retArea.ptr + 32)))) != 0;
        if (_isSome4) {
          core.sys.wasi.p2.clocks.wall_clock.imports.Datetime _record3 = {
            seconds: *(cast(ulong*)(_retArea.ptr + 40)),
            nanoseconds: *(cast(uint*)(_retArea.ptr + 48)),
          };

          _option4 = Option!(Datetime).some(_record3);
        } else {
          _option4 = Option!(Datetime).none;
        }
        Option!(Datetime) _option8 = void;
        bool _isSome8 = (cast(uint)(*(cast(ubyte*)(_retArea.ptr + 56)))) != 0;
        if (_isSome8) {
          core.sys.wasi.p2.clocks.wall_clock.imports.Datetime _record7 = {
            seconds: *(cast(ulong*)(_retArea.ptr + 64)),
            nanoseconds: *(cast(uint*)(_retArea.ptr + 72)),
          };

          _option8 = Option!(Datetime).some(_record7);
        } else {
          _option8 = Option!(Datetime).none;
        }
        Option!(Datetime) _option12 = void;
        bool _isSome12 = (cast(uint)(*(cast(ubyte*)(_retArea.ptr + 80)))) != 0;
        if (_isSome12) {
          core.sys.wasi.p2.clocks.wall_clock.imports.Datetime _record11 = {
            seconds: *(cast(ulong*)(_retArea.ptr + 88)),
            nanoseconds: *(cast(uint*)(_retArea.ptr + 96)),
          };

          _option12 = Option!(Datetime).some(_record11);
        } else {
          _option12 = Option!(Datetime).none;
        }
        DescriptorStat _record13 = {
          type: cast(DescriptorType)(cast(uint)(*(cast(ubyte*)(_retArea.ptr + 8)))),
          linkCount: *(cast(ulong*)(_retArea.ptr + 16)),
          size: *(cast(ulong*)(_retArea.ptr + 24)),
          dataAccessTimestamp: _option4,
          dataModificationTimestamp: _option8,
          statusChangeTimestamp: _option12,
        };

        _result15 = Result!(DescriptorStat, ErrorCode).ok(_record13);
      }
      auto _flush16 = _result15;
      return _flush16;
    }
    /// ditto
    @wasmImport!("wasi:filesystem/types@0.2.12", "[method]descriptor.stat")
    pragma(mangle, "__wit_import_wasi:filesystem__types@0.2.12__:method:descriptor.stat")
    static private extern(C) void __import_stat(uint, void*) @nogc nothrow;

    /++

    +/
    Result!(DescriptorStat, ErrorCode) statAt(in PathFlags pathFlags, in WitString path) @nogc nothrow {
      align(8) void[104] _retArea = void;
      __import_statAt(this.__handle, cast(uint)(pathFlags.bits), cast(void*)(path.ptr), path.length, _retArea.ptr);
      Result!(DescriptorStat, ErrorCode) _result15 = void;
      bool _isErr15 = (cast(uint)(*(cast(ubyte*)(_retArea.ptr + 0)))) != 0;
      if (_isErr15) {

        _result15 = Result!(DescriptorStat, ErrorCode).err(cast(ErrorCode)(cast(uint)(*(cast(ubyte*)(_retArea.ptr + 8)))));
      } else {
        Option!(Datetime) _option4 = void;
        bool _isSome4 = (cast(uint)(*(cast(ubyte*)(_retArea.ptr + 32)))) != 0;
        if (_isSome4) {
          core.sys.wasi.p2.clocks.wall_clock.imports.Datetime _record3 = {
            seconds: *(cast(ulong*)(_retArea.ptr + 40)),
            nanoseconds: *(cast(uint*)(_retArea.ptr + 48)),
          };

          _option4 = Option!(Datetime).some(_record3);
        } else {
          _option4 = Option!(Datetime).none;
        }
        Option!(Datetime) _option8 = void;
        bool _isSome8 = (cast(uint)(*(cast(ubyte*)(_retArea.ptr + 56)))) != 0;
        if (_isSome8) {
          core.sys.wasi.p2.clocks.wall_clock.imports.Datetime _record7 = {
            seconds: *(cast(ulong*)(_retArea.ptr + 64)),
            nanoseconds: *(cast(uint*)(_retArea.ptr + 72)),
          };

          _option8 = Option!(Datetime).some(_record7);
        } else {
          _option8 = Option!(Datetime).none;
        }
        Option!(Datetime) _option12 = void;
        bool _isSome12 = (cast(uint)(*(cast(ubyte*)(_retArea.ptr + 80)))) != 0;
        if (_isSome12) {
          core.sys.wasi.p2.clocks.wall_clock.imports.Datetime _record11 = {
            seconds: *(cast(ulong*)(_retArea.ptr + 88)),
            nanoseconds: *(cast(uint*)(_retArea.ptr + 96)),
          };

          _option12 = Option!(Datetime).some(_record11);
        } else {
          _option12 = Option!(Datetime).none;
        }
        DescriptorStat _record13 = {
          type: cast(DescriptorType)(cast(uint)(*(cast(ubyte*)(_retArea.ptr + 8)))),
          linkCount: *(cast(ulong*)(_retArea.ptr + 16)),
          size: *(cast(ulong*)(_retArea.ptr + 24)),
          dataAccessTimestamp: _option4,
          dataModificationTimestamp: _option8,
          statusChangeTimestamp: _option12,
        };

        _result15 = Result!(DescriptorStat, ErrorCode).ok(_record13);
      }
      auto _flush16 = _result15;
      return _flush16;
    }
    /// ditto
    @wasmImport!("wasi:filesystem/types@0.2.12", "[method]descriptor.stat-at")
    pragma(mangle, "__wit_import_wasi:filesystem__types@0.2.12__:method:descriptor.stat_at")
    static private extern(C) void __import_statAt(uint, uint, void*, size_t, void*) @nogc nothrow;

    /++

    +/
    Result!(void, ErrorCode) setTimesAt(in PathFlags pathFlags, in WitString path, in NewTimestamp dataAccessTimestamp, in NewTimestamp dataModificationTimestamp) @nogc nothrow {
      align(1) void[2] _retArea = void;
      uint _variantPart6 = void;
      ulong _variantPart7 = void;
      uint _variantPart8 = void;
      alias _Tag9 = NewTimestamp.Tag;
      final switch (dataAccessTimestamp.tag) {
        case _Tag9.noChange: {
          _variantPart6 = 0;
          _variantPart7 = 0;
          _variantPart8 = 0;
          break;
        }
        case _Tag9.now: {
          _variantPart6 = 1;
          _variantPart7 = 0;
          _variantPart8 = 0;
          break;
        }
        case _Tag9.timestamp: {
          const ref Datetime _payload5 = dataAccessTimestamp.getTimestamp();
          _variantPart6 = 2;
          _variantPart7 = _payload5.seconds;
          _variantPart8 = _payload5.nanoseconds;
          break;
        }
      }
      uint _variantPart16 = void;
      ulong _variantPart17 = void;
      uint _variantPart18 = void;
      alias _Tag19 = NewTimestamp.Tag;
      final switch (dataModificationTimestamp.tag) {
        case _Tag19.noChange: {
          _variantPart16 = 0;
          _variantPart17 = 0;
          _variantPart18 = 0;
          break;
        }
        case _Tag19.now: {
          _variantPart16 = 1;
          _variantPart17 = 0;
          _variantPart18 = 0;
          break;
        }
        case _Tag19.timestamp: {
          const ref Datetime _payload15 = dataModificationTimestamp.getTimestamp();
          _variantPart16 = 2;
          _variantPart17 = _payload15.seconds;
          _variantPart18 = _payload15.nanoseconds;
          break;
        }
      }
      __import_setTimesAt(this.__handle, cast(uint)(pathFlags.bits), cast(void*)(path.ptr), path.length, _variantPart6, _variantPart7, _variantPart8, _variantPart16, _variantPart17, _variantPart18, _retArea.ptr);
      Result!(void, ErrorCode) _result22 = void;
      bool _isErr22 = (cast(uint)(*(cast(ubyte*)(_retArea.ptr + 0)))) != 0;
      if (_isErr22) {

        _result22 = Result!(void, ErrorCode).err(cast(ErrorCode)(cast(uint)(*(cast(ubyte*)(_retArea.ptr + 1)))));
      } else {

        _result22 = Result!(void, ErrorCode).ok();
      }
      auto _flush23 = _result22;
      return _flush23;
    }
    /// ditto
    @wasmImport!("wasi:filesystem/types@0.2.12", "[method]descriptor.set-times-at")
    pragma(mangle, "__wit_import_wasi:filesystem__types@0.2.12__:method:descriptor.set_times_at")
    static private extern(C) void __import_setTimesAt(uint, uint, void*, size_t, uint, ulong, uint, uint, ulong, uint, void*) @nogc nothrow;

    /++

    +/
    Result!(void, ErrorCode) linkAt(in PathFlags oldPathFlags, in WitString oldPath, in Descriptor.Borrow newDescriptor, in WitString newPath) @nogc nothrow {
      align(1) void[2] _retArea = void;
      __import_linkAt(this.__handle, cast(uint)(oldPathFlags.bits), cast(void*)(oldPath.ptr), oldPath.length, newDescriptor.__handle, cast(void*)(newPath.ptr), newPath.length, _retArea.ptr);
      Result!(void, ErrorCode) _result2 = void;
      bool _isErr2 = (cast(uint)(*(cast(ubyte*)(_retArea.ptr + 0)))) != 0;
      if (_isErr2) {

        _result2 = Result!(void, ErrorCode).err(cast(ErrorCode)(cast(uint)(*(cast(ubyte*)(_retArea.ptr + 1)))));
      } else {

        _result2 = Result!(void, ErrorCode).ok();
      }
      auto _flush3 = _result2;
      return _flush3;
    }
    /// ditto
    @wasmImport!("wasi:filesystem/types@0.2.12", "[method]descriptor.link-at")
    pragma(mangle, "__wit_import_wasi:filesystem__types@0.2.12__:method:descriptor.link_at")
    static private extern(C) void __import_linkAt(uint, uint, void*, size_t, uint, void*, size_t, void*) @nogc nothrow;

    /++

    +/
    Result!(Descriptor, ErrorCode) openAt(in PathFlags pathFlags, in WitString path, in OpenFlags openFlags, in DescriptorFlags flags) @nogc nothrow {
      align(4) void[8] _retArea = void;
      __import_openAt(this.__handle, cast(uint)(pathFlags.bits), cast(void*)(path.ptr), path.length, cast(uint)(openFlags.bits), cast(uint)(flags.bits), _retArea.ptr);
      Result!(Descriptor, ErrorCode) _result2 = void;
      bool _isErr2 = (cast(uint)(*(cast(ubyte*)(_retArea.ptr + 0)))) != 0;
      if (_isErr2) {

        _result2 = Result!(Descriptor, ErrorCode).err(cast(ErrorCode)(cast(uint)(*(cast(ubyte*)(_retArea.ptr + 4)))));
      } else {

        _result2 = Result!(Descriptor, ErrorCode).ok(Descriptor(*(cast(uint*)(_retArea.ptr + 4))));
      }
      auto _flush3 = _result2;
      return _flush3;
    }
    /// ditto
    @wasmImport!("wasi:filesystem/types@0.2.12", "[method]descriptor.open-at")
    pragma(mangle, "__wit_import_wasi:filesystem__types@0.2.12__:method:descriptor.open_at")
    static private extern(C) void __import_openAt(uint, uint, void*, size_t, uint, uint, void*) @nogc nothrow;

    /++

    +/
    Result!(WitString, ErrorCode) readlinkAt(in WitString path) @nogc nothrow {
      align(size_t.sizeof) void[(3*size_t.sizeof)] _retArea = void;
      __import_readlinkAt(this.__handle, cast(void*)(path.ptr), path.length, _retArea.ptr);
      Result!(WitString, ErrorCode) _result3 = void;
      bool _isErr3 = (cast(uint)(*(cast(ubyte*)(_retArea.ptr + 0)))) != 0;
      if (_isErr3) {

        _result3 = Result!(WitString, ErrorCode).err(cast(ErrorCode)(cast(uint)(*(cast(ubyte*)(_retArea.ptr + size_t.sizeof)))));
      } else {
        auto _ptr1 = cast(char*)(*(cast(void**)(_retArea.ptr + size_t.sizeof)));
        auto _len1 = *(cast(size_t*)(_retArea.ptr + (2*size_t.sizeof)));

        _result3 = Result!(WitString, ErrorCode).ok(WitString(_ptr1[0.._len1]));
      }
      auto _flush4 = _result3;
      return _flush4;
    }
    /// ditto
    @wasmImport!("wasi:filesystem/types@0.2.12", "[method]descriptor.readlink-at")
    pragma(mangle, "__wit_import_wasi:filesystem__types@0.2.12__:method:descriptor.readlink_at")
    static private extern(C) void __import_readlinkAt(uint, void*, size_t, void*) @nogc nothrow;

    /++

    +/
    Result!(void, ErrorCode) removeDirectoryAt(in WitString path) @nogc nothrow {
      align(1) void[2] _retArea = void;
      __import_removeDirectoryAt(this.__handle, cast(void*)(path.ptr), path.length, _retArea.ptr);
      Result!(void, ErrorCode) _result2 = void;
      bool _isErr2 = (cast(uint)(*(cast(ubyte*)(_retArea.ptr + 0)))) != 0;
      if (_isErr2) {

        _result2 = Result!(void, ErrorCode).err(cast(ErrorCode)(cast(uint)(*(cast(ubyte*)(_retArea.ptr + 1)))));
      } else {

        _result2 = Result!(void, ErrorCode).ok();
      }
      auto _flush3 = _result2;
      return _flush3;
    }
    /// ditto
    @wasmImport!("wasi:filesystem/types@0.2.12", "[method]descriptor.remove-directory-at")
    pragma(mangle, "__wit_import_wasi:filesystem__types@0.2.12__:method:descriptor.remove_directory_at")
    static private extern(C) void __import_removeDirectoryAt(uint, void*, size_t, void*) @nogc nothrow;

    /++

    +/
    Result!(void, ErrorCode) renameAt(in WitString oldPath, in Descriptor.Borrow newDescriptor, in WitString newPath) @nogc nothrow {
      align(1) void[2] _retArea = void;
      __import_renameAt(this.__handle, cast(void*)(oldPath.ptr), oldPath.length, newDescriptor.__handle, cast(void*)(newPath.ptr), newPath.length, _retArea.ptr);
      Result!(void, ErrorCode) _result2 = void;
      bool _isErr2 = (cast(uint)(*(cast(ubyte*)(_retArea.ptr + 0)))) != 0;
      if (_isErr2) {

        _result2 = Result!(void, ErrorCode).err(cast(ErrorCode)(cast(uint)(*(cast(ubyte*)(_retArea.ptr + 1)))));
      } else {

        _result2 = Result!(void, ErrorCode).ok();
      }
      auto _flush3 = _result2;
      return _flush3;
    }
    /// ditto
    @wasmImport!("wasi:filesystem/types@0.2.12", "[method]descriptor.rename-at")
    pragma(mangle, "__wit_import_wasi:filesystem__types@0.2.12__:method:descriptor.rename_at")
    static private extern(C) void __import_renameAt(uint, void*, size_t, uint, void*, size_t, void*) @nogc nothrow;

    /++

    +/
    Result!(void, ErrorCode) symlinkAt(in WitString oldPath, in WitString newPath) @nogc nothrow {
      align(1) void[2] _retArea = void;
      __import_symlinkAt(this.__handle, cast(void*)(oldPath.ptr), oldPath.length, cast(void*)(newPath.ptr), newPath.length, _retArea.ptr);
      Result!(void, ErrorCode) _result2 = void;
      bool _isErr2 = (cast(uint)(*(cast(ubyte*)(_retArea.ptr + 0)))) != 0;
      if (_isErr2) {

        _result2 = Result!(void, ErrorCode).err(cast(ErrorCode)(cast(uint)(*(cast(ubyte*)(_retArea.ptr + 1)))));
      } else {

        _result2 = Result!(void, ErrorCode).ok();
      }
      auto _flush3 = _result2;
      return _flush3;
    }
    /// ditto
    @wasmImport!("wasi:filesystem/types@0.2.12", "[method]descriptor.symlink-at")
    pragma(mangle, "__wit_import_wasi:filesystem__types@0.2.12__:method:descriptor.symlink_at")
    static private extern(C) void __import_symlinkAt(uint, void*, size_t, void*, size_t, void*) @nogc nothrow;

    /++

    +/
    Result!(void, ErrorCode) unlinkFileAt(in WitString path) @nogc nothrow {
      align(1) void[2] _retArea = void;
      __import_unlinkFileAt(this.__handle, cast(void*)(path.ptr), path.length, _retArea.ptr);
      Result!(void, ErrorCode) _result2 = void;
      bool _isErr2 = (cast(uint)(*(cast(ubyte*)(_retArea.ptr + 0)))) != 0;
      if (_isErr2) {

        _result2 = Result!(void, ErrorCode).err(cast(ErrorCode)(cast(uint)(*(cast(ubyte*)(_retArea.ptr + 1)))));
      } else {

        _result2 = Result!(void, ErrorCode).ok();
      }
      auto _flush3 = _result2;
      return _flush3;
    }
    /// ditto
    @wasmImport!("wasi:filesystem/types@0.2.12", "[method]descriptor.unlink-file-at")
    pragma(mangle, "__wit_import_wasi:filesystem__types@0.2.12__:method:descriptor.unlink_file_at")
    static private extern(C) void __import_unlinkFileAt(uint, void*, size_t, void*) @nogc nothrow;

    /++

    +/
    bool isSameObject(in Descriptor.Borrow other) @nogc nothrow {
      auto _ret = __import_isSameObject(this.__handle, other.__handle);
      return (_ret) != 0;
    }
    /// ditto
    @wasmImport!("wasi:filesystem/types@0.2.12", "[method]descriptor.is-same-object")
    pragma(mangle, "__wit_import_wasi:filesystem__types@0.2.12__:method:descriptor.is_same_object")
    static private extern(C) uint __import_isSameObject(uint, uint) @nogc nothrow;

    /++

    +/
    Result!(MetadataHashValue, ErrorCode) metadataHash() @nogc nothrow {
      align(8) void[24] _retArea = void;
      __import_metadataHash(this.__handle, _retArea.ptr);
      Result!(MetadataHashValue, ErrorCode) _result3 = void;
      bool _isErr3 = (cast(uint)(*(cast(ubyte*)(_retArea.ptr + 0)))) != 0;
      if (_isErr3) {

        _result3 = Result!(MetadataHashValue, ErrorCode).err(cast(ErrorCode)(cast(uint)(*(cast(ubyte*)(_retArea.ptr + 8)))));
      } else {
        MetadataHashValue _record1 = {
          lower: *(cast(ulong*)(_retArea.ptr + 8)),
          upper: *(cast(ulong*)(_retArea.ptr + 16)),
        };

        _result3 = Result!(MetadataHashValue, ErrorCode).ok(_record1);
      }
      auto _flush4 = _result3;
      return _flush4;
    }
    /// ditto
    @wasmImport!("wasi:filesystem/types@0.2.12", "[method]descriptor.metadata-hash")
    pragma(mangle, "__wit_import_wasi:filesystem__types@0.2.12__:method:descriptor.metadata_hash")
    static private extern(C) void __import_metadataHash(uint, void*) @nogc nothrow;

    /++

    +/
    Result!(MetadataHashValue, ErrorCode) metadataHashAt(in PathFlags pathFlags, in WitString path) @nogc nothrow {
      align(8) void[24] _retArea = void;
      __import_metadataHashAt(this.__handle, cast(uint)(pathFlags.bits), cast(void*)(path.ptr), path.length, _retArea.ptr);
      Result!(MetadataHashValue, ErrorCode) _result3 = void;
      bool _isErr3 = (cast(uint)(*(cast(ubyte*)(_retArea.ptr + 0)))) != 0;
      if (_isErr3) {

        _result3 = Result!(MetadataHashValue, ErrorCode).err(cast(ErrorCode)(cast(uint)(*(cast(ubyte*)(_retArea.ptr + 8)))));
      } else {
        MetadataHashValue _record1 = {
          lower: *(cast(ulong*)(_retArea.ptr + 8)),
          upper: *(cast(ulong*)(_retArea.ptr + 16)),
        };

        _result3 = Result!(MetadataHashValue, ErrorCode).ok(_record1);
      }
      auto _flush4 = _result3;
      return _flush4;
    }
    /// ditto
    @wasmImport!("wasi:filesystem/types@0.2.12", "[method]descriptor.metadata-hash-at")
    pragma(mangle, "__wit_import_wasi:filesystem__types@0.2.12__:method:descriptor.metadata_hash_at")
    static private extern(C) void __import_metadataHashAt(uint, uint, void*, size_t, void*) @nogc nothrow;
  }
}

/++

+/
struct DirectoryEntryStream {
  @nogc nothrow:

  package(core.sys.wasi.p2) uint __handle = 0;

  package(core.sys.wasi.p2) this(uint handle) {
    __handle = handle;
  }

  @disable this();


  void drop() {
    __import_drop(__handle);
  }
  @wasmImport!("wasi:filesystem/types@0.2.12", "[resource-drop]directory-entry-stream")
  pragma(mangle, "__wit_import_wasi:filesystem__types@0.2.12__:resource_drop:directory_entry_stream")
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
    Result!(Option!(DirectoryEntry), ErrorCode) readDirectoryEntry() @nogc nothrow {
      align(size_t.sizeof) void[(5*size_t.sizeof)] _retArea = void;
      __import_readDirectoryEntry(this.__handle, _retArea.ptr);
      Result!(Option!(DirectoryEntry), ErrorCode) _result7 = void;
      bool _isErr7 = (cast(uint)(*(cast(ubyte*)(_retArea.ptr + 0)))) != 0;
      if (_isErr7) {

        _result7 = Result!(Option!(DirectoryEntry), ErrorCode).err(cast(ErrorCode)(cast(uint)(*(cast(ubyte*)(_retArea.ptr + size_t.sizeof)))));
      } else {
        Option!(DirectoryEntry) _option5 = void;
        bool _isSome5 = (cast(uint)(*(cast(ubyte*)(_retArea.ptr + size_t.sizeof)))) != 0;
        if (_isSome5) {
          auto _ptr3 = cast(char*)(*(cast(void**)(_retArea.ptr + (3*size_t.sizeof))));
          auto _len3 = *(cast(size_t*)(_retArea.ptr + (4*size_t.sizeof)));
          DirectoryEntry _record4 = {
            type: cast(DescriptorType)(cast(uint)(*(cast(ubyte*)(_retArea.ptr + (2*size_t.sizeof))))),
            name: WitString(_ptr3[0.._len3]),
          };

          _option5 = Option!(DirectoryEntry).some(_record4);
        } else {
          _option5 = Option!(DirectoryEntry).none;
        }

        _result7 = Result!(Option!(DirectoryEntry), ErrorCode).ok(_option5);
      }
      auto _flush8 = _result7;
      return _flush8;
    }
    /// ditto
    @wasmImport!("wasi:filesystem/types@0.2.12", "[method]directory-entry-stream.read-directory-entry")
    pragma(mangle, "__wit_import_wasi:filesystem__types@0.2.12__:method:directory_entry_stream.read_directory_entry")
    static private extern(C) void __import_readDirectoryEntry(uint, void*) @nogc nothrow;
  }
}

/++

+/
Option!(ErrorCode) filesystemErrorCode(in Error_.Borrow err) @nogc nothrow {
  align(1) void[2] _retArea = void;
  __import_filesystemErrorCode(err.__handle, _retArea.ptr);
  Option!(ErrorCode) _option2 = void;
  bool _isSome2 = (cast(uint)(*(cast(ubyte*)(_retArea.ptr + 0)))) != 0;
  if (_isSome2) {

    _option2 = Option!(ErrorCode).some(cast(ErrorCode)(cast(uint)(*(cast(ubyte*)(_retArea.ptr + 1)))));
  } else {
    _option2 = Option!(ErrorCode).none;
  }
  auto _flush3 = _option2;
  return _flush3;
}
/// ditto
@wasmImport!("wasi:filesystem/types@0.2.12", "filesystem-error-code")
pragma(mangle, "__wit_import_wasi:filesystem__types@0.2.12__filesystem_error_code")
private extern(C) void __import_filesystemErrorCode(uint, void*) @nogc nothrow;
