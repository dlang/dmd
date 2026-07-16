/++

+/
module core.sys.wasi.p2.filesystem.types.common;

import core.sys.wasi.wit_common;

static import core.sys.wasi.p2.io.streams.common;
static import core.sys.wasi.p2.clocks.wall_clock.common;

package (core.sys.wasi.p2) void __wit_bindgen_component_type_force_link() pure @nogc nothrow => imported!"core.sys.wasi.p2.cli.imports".__wit_bindgen_component_type_force_link();

/++

+/
alias Datetime = core.sys.wasi.p2.clocks.wall_clock.common.Datetime;

/++

+/
alias Filesize = ulong;

/++

+/
enum DescriptorType : ubyte {
  /++

  +/
  unknown,

  /++

  +/
  blockDevice,

  /++

  +/
  characterDevice,

  /++

  +/
  directory,

  /++

  +/
  fifo,

  /++

  +/
  symbolicLink,

  /++

  +/
  regularFile,

  /++

  +/
  socket,
}
/++

+/
struct DescriptorFlags {
  mixin WitFlags!ubyte;

  /++

  +/
  enum read = DescriptorFlags[0];

  /++

  +/
  enum write = DescriptorFlags[1];

  /++

  +/
  enum fileIntegritySync = DescriptorFlags[2];

  /++

  +/
  enum dataIntegritySync = DescriptorFlags[3];

  /++

  +/
  enum requestedWriteSync = DescriptorFlags[4];

  /++

  +/
  enum mutateDirectory = DescriptorFlags[5];
}

/++

+/
struct PathFlags {
  mixin WitFlags!ubyte;

  /++

  +/
  enum symlinkFollow = PathFlags[0];
}

/++

+/
struct OpenFlags {
  mixin WitFlags!ubyte;

  /++

  +/
  enum create = OpenFlags[0];

  /++

  +/
  enum directory = OpenFlags[1];

  /++

  +/
  enum exclusive = OpenFlags[2];

  /++

  +/
  enum truncate = OpenFlags[3];
}

/++

+/
alias LinkCount = ulong;

/++

+/
struct DescriptorStat {
  /++

  +/
  DescriptorType type;

  /++

  +/
  LinkCount linkCount;

  /++

  +/
  Filesize size;

  /++

  +/
  Option!(Datetime) dataAccessTimestamp;

  /++

  +/
  Option!(Datetime) dataModificationTimestamp;

  /++

  +/
  Option!(Datetime) statusChangeTimestamp;

  void witFree() @nogc nothrow {
  }

  DescriptorStat witClone() const @nogc nothrow {
    DescriptorStat clone = void;
    clone.type = this.type.witClone;
    clone.linkCount = this.linkCount.witClone;
    clone.size = this.size.witClone;
    clone.dataAccessTimestamp = this.dataAccessTimestamp.witClone;
    clone.dataModificationTimestamp = this.dataModificationTimestamp.witClone;
    clone.statusChangeTimestamp = this.statusChangeTimestamp.witClone;
    return clone;
  }
}

/++

+/
struct NewTimestamp {
  mixin WitVariant!(
    void, // noChange
    void, // now
    Datetime, // timestamp
  );

public:
  enum Tag : ubyte {
    /++

    +/
    noChange,

    /++

    +/
    now,

    /++

    +/
    timestamp,
  }
  Tag tag() const @safe @nogc nothrow pure => _tag;

  /++

  +/
  alias noChange = _create!(Tag.noChange);
  /// ditto
  bool isNoChange() const => _tag == Tag.noChange;

  /++

  +/
  alias now = _create!(Tag.now);
  /// ditto
  bool isNow() const => _tag == Tag.now;

  /++

  +/
  alias timestamp = _create!(Tag.timestamp);
  /// ditto
  bool isTimestamp() const => _tag == Tag.timestamp;
  ///ditto
  alias getTimestamp = _get!(Tag.timestamp);

  void witFree() @nogc nothrow {
  }

  NewTimestamp witClone() const @nogc nothrow {
    final switch (_tag) {
      case Tag.noChange: return _create!(Tag.noChange); break;
      case Tag.now: return _create!(Tag.now); break;
      case Tag.timestamp: return _create!(Tag.timestamp)(this._get!(Tag.timestamp).witClone); break;
    }
  }
}

/++

+/
struct DirectoryEntry {
  /++

  +/
  DescriptorType type;

  /++

  +/
  WitString name;

  void witFree() @nogc nothrow {
    name.witFree;
  }

  DirectoryEntry witClone() const @nogc nothrow {
    DirectoryEntry clone = void;
    clone.type = this.type.witClone;
    clone.name = this.name.witClone;
    return clone;
  }
}

/++

+/
enum ErrorCode : ubyte {
  /++

  +/
  access,

  /++

  +/
  wouldBlock,

  /++

  +/
  already,

  /++

  +/
  badDescriptor,

  /++

  +/
  busy,

  /++

  +/
  deadlock,

  /++

  +/
  quota,

  /++

  +/
  exist,

  /++

  +/
  fileTooLarge,

  /++

  +/
  illegalByteSequence,

  /++

  +/
  inProgress,

  /++

  +/
  interrupted,

  /++

  +/
  invalid,

  /++

  +/
  io,

  /++

  +/
  isDirectory,

  /++

  +/
  loop,

  /++

  +/
  tooManyLinks,

  /++

  +/
  messageSize,

  /++

  +/
  nameTooLong,

  /++

  +/
  noDevice,

  /++

  +/
  noEntry,

  /++

  +/
  noLock,

  /++

  +/
  insufficientMemory,

  /++

  +/
  insufficientSpace,

  /++

  +/
  notDirectory,

  /++

  +/
  notEmpty,

  /++

  +/
  notRecoverable,

  /++

  +/
  unsupported,

  /++

  +/
  noTty,

  /++

  +/
  noSuchDevice,

  /++

  +/
  overflow,

  /++

  +/
  notPermitted,

  /++

  +/
  pipe,

  /++

  +/
  readOnly,

  /++

  +/
  invalidSeek,

  /++

  +/
  textFileBusy,

  /++

  +/
  crossDevice,
}
/++

+/
enum Advice : ubyte {
  /++

  +/
  normal,

  /++

  +/
  sequential,

  /++

  +/
  random,

  /++

  +/
  willNeed,

  /++

  +/
  dontNeed,

  /++

  +/
  noReuse,
}
/++

+/
struct MetadataHashValue {
  /++

  +/
  ulong lower;

  /++

  +/
  ulong upper;

  void witFree() @nogc nothrow {
  }

  MetadataHashValue witClone() const @nogc nothrow {
    MetadataHashValue clone = void;
    clone.lower = this.lower.witClone;
    clone.upper = this.upper.witClone;
    return clone;
  }
}
