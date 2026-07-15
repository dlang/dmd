/**
 * D bindings for WASI preview1.
 *
 * Based on `wasi-libc`'s `wasi/wasip1.h`, adjusted to be more idiomatic D.
 *
 * We bind and wrap the "syscalls" directly, rather than using the wrappers
 * provided by `wasi-libc`.
 *
 * Standards: $(LINK2 https://github.com/WebAssembly/WASI/tree/wasi-0.1/, WebAssembly System Interface (WASI) snapshot preview1)
 */
module core.sys.wasi.p1;

version (WASIp1):

version (D_LP64) static assert(0, "WASIp1 is only supported on wasm32, not wasm64");

version (LDC) {
    import ldc.attributes : llvmAttr;

    private alias AliasSeq(T...) = T;
    private alias wasiImport(string name) = AliasSeq!(
        llvmAttr("wasm-import-module", "wasi_snapshot_preview1"),
        llvmAttr("wasm-import-name", name)
    );
} else static assert("Unknown compiler for WASI.");

@nogc nothrow:

static assert(byte.alignof == 1, "non-wasi data layout");
static assert(ubyte.alignof == 1, "non-wasi data layout");
static assert(short.alignof == 2, "non-wasi data layout");
static assert(ushort.alignof == 2, "non-wasi data layout");
static assert(int.alignof == 4, "non-wasi data layout");
static assert(uint.alignof == 4, "non-wasi data layout");
static assert(long.alignof == 8, "non-wasi data layout");
static assert(ulong.alignof == 8, "non-wasi data layout");
static assert((void*).alignof == 4, "non-wasi data layout");

static assert(size_t.sizeof == 4, "witx calculated size");
static assert(size_t.alignof == 4, "witx calculated align");

/// Non-negative file size or length of a region within a file.
alias FileSize = ulong;

/// Timestamp in nanoseconds.
alias Timestamp = ulong;

/// Identifiers for clocks.
enum ClockID : uint {
    /// The clock measuring real time.
    /// Time value zero corresponds with 1970-01-01T00:00:00Z.
    realtime,

    /**
     * The store-wide monotonic clock, which is defined as a clock measuring
     * real time, whose value cannot be adjusted and which cannot have
     * negative clock jumps.
     *
     * The epoch of this clock is undefined. The absolute time value of this
     * clock therefore has no meaning.
     */
    monotonic,

    /// The CPU-time clock associated with the current process.
    processCPUTimeID,

    /// The CPU-time clock associated with the current thread.
    threadCPUTimeID
}

/**
 * Error codes returned by functions. Not all of these error codes are
 * returned by the functions provided by this API; some are used in
 * higher-level library layers, and others are provided merely for
 * alignment with POSIX.
 */
enum Errno : ushort {
    /// No error occurred. System call completed successfully.
    success,

    /// Argument list too long.
    _2big,

    /// Permission denied.
    acces,

    /// Address in use.
    addrinuse,

    /// Address not available.
    addrnotavail,

    /// Address family not supported.
    afnosupport,

    /// Resource unavailable, or operation would block.
    again,

    /// Connection already in progress.
    already,

    /// Bad file descriptor.
    badf,

    /// Bad message.
    badmsg,

    /// Device or resource busy.
    busy,

    /// Operation canceled.
    canceled,

    /// No child processes.
    child,

    /// Connection aborted.
    connaborted,

    /// Connection refused.
    connrefused,

    /// Connection reset.
    connreset,

    /// Resource deadlock would occur.
    deadlk,

    /// Destination address required.
    destaddrreq,

    /// Mathematics argument out of domain of function.
    dom,

    /// Reserved.
    dquot,

    /// File exists.
    exist,

    /// Bad address.
    fault,

    /// File too large.
    fbig,

    /// Host is unreachable.
    hostunreach,

    /// Identifier removed.
    idrm,

    /// Illegal byte sequence.
    ilseq,

    /// Operation in progress.
    inprogress,

    /// Interrupted function.
    intr,

    /// Invalid argument.
    inval,

    /// I/O error.
    io,

    /// Socket is connected.
    isconn,

    /// Is a directory.
    isdir,

    /// Too many levels of symbolic links.
    loop,

    /// File descriptor value too large.
    mfile,

    /// Too many links.
    mlink,

    /// Message too large.
    msgsize,

    /// Reserved.
    multihop,

    /// Filename too long.
    nametoolong,

    /// Network is down.
    netdown,

    /// Connection aborted by network.
    netreset,

    /// Network unreachable.
    netunreach,

    /// Too many files open in system.
    nfile,

    /// No buffer space available.
    nobufs,

    /// No such device.
    nodev,

    /// No such file or directory.
    noent,

    /// Executable file format error.
    noexec,

    /// No locks available.
    nolck,

    /// Reserved.
    nolink,

    /// Not enough space.
    nomem,

    /// No message of the desired type.
    nomsg,

    /// Protocol not available.
    noprotoopt,

    /// No space left on device.
    nospc,

    /// Function not supported.
    nosys,

    /// The socket is not connected.
    notconn,

    /// Not a directory or a symbolic link to a directory.
    notdir,

    /// Directory not empty.
    notempty,

    /// State not recoverable.
    notrecoverable,

    /// Not a socket.
    notsock,

    /// Not supported, or operation not supported on socket.
    notsup,

    /// Inappropriate I/O control operation.
    notty,

    /// No such device or address.
    nxio,

    /// Value too large to be stored in data type.
    overflow,

    /// Previous owner died.
    ownerdead,

    /// Operation not permitted.
    perm,

    /// Broken pipe.
    pipe,

    /// Protocol error.
    proto,

    /// Protocol not supported.
    protonosupport,

    /// Protocol wrong type for socket.
    prototype,

    /// Result too large.
    range,

    /// Read-only file system.
    rofs,

    /// Invalid seek.
    spipe,

    /// No such process.
    srch,

    /// Reserved.
    stale,

    /// Connection timed out.
    timedout,

    /// Text file busy.
    txtbsy,

    /// Cross-device link.
    xdev,

    /// Extension: Capabilities insufficient.
    notcapable
}

/// File descriptor rights, determining which actions may be performed.
enum Rights : ulong {
    /// The right to invoke `.fdDataSync`.
    /// If `pathOpen` is set, includes the right to invoke
    /// `.pathOpen` with `FdFlags.dsync`.
    fdDataSync = (1 << 0),

    /// The right to invoke `.fdRead` and `.sockRecv`.
    /// If `Rights.fdSeek` is set, includes the right to invoke `.fdPread`.
    fdRead = (1 << 1),

    /// The right to invoke `.fdSeek`.
    /// This flag implies `fdTell`.
    fdSeek = (1 << 2),

    /// The right to invoke `.fdFdstatSetFlags`.
    fdFdstatSetFlags = (1 << 3),

    /// The right to invoke `.fdSync`.
    /// If `pathOpen` is set, includes the right to invoke
    /// `.pathOpen` with `FdFlags.rsync` and `FdFlags.dsync`.
    fdSync = (1 << 4),

    /// The right to invoke `.fdSeek` in such a way that the
    /// file offset remains unaltered (i.e., `Whence.cur` with offset zero),
    /// or to invoke `.fdTell`.
    fdTell = (1 << 5),

    /// The right to invoke `.fdWrite` and `.sockSend`.
    /// If `fdSeek` is set, includes the right to invoke `.fdPwrite`.
    fdWrite = (1 << 6),

    /// The right to invoke `.fdAdvise`.
    fdAdvise = (1 << 7),

    /// The right to invoke `.fdAllocate`.
    fdAllocate = (1 << 8),

    /// The right to invoke `.pathCreateDirectory`.
    pathCreateDirectory = (1 << 9),

    /// If `pathOpen` is set, the right to invoke
    /// `.pathOpen` with `OFlags.create`.
    pathCreateFile = (1 << 10),

    /// The right to invoke `.pathLink` with the file descriptor
    /// as the source directory.
    pathLinkSource = (1 << 11),

    /// The right to invoke `.pathLink` with the file descriptor as the target.
    pathLinkTarget = (1 << 12),

    /// The right to invoke `.pathOpen`.
    pathOpen = (1 << 13),

    /// The right to invoke `.fdReadDir`.
    fdReadDir = (1 << 14),

    /// The right to invoke `.pathReadLink`.
    pathReadLink = (1 << 15),

    /// The right to invoke `.pathRename` with the source file descriptor.
    pathRenameSource = (1 << 16),

    /// The right to invoke `.pathRename` with the target file descriptor.
    pathRenameTarget = (1 << 17),

    /// The right to invoke `.pathFilestatGet`.
    pathFilestatGet = (1 << 18),

    /**
     * The right to change a file's size. If `pathOpen` is set, includes the
     * right to invoke `.pathOpen` with `OFlags.trunc`.
     * Note:
     *   There is no function named `pathFilestatSetSize`.
     *   This follows POSIX design, which only has `ftruncate`
     *   and does not provide `ftruncateat`.
     */
    pathFilestatSetSize = (1 << 19),

    /// The right to invoke `.pathFilestatSetTimes`.
    pathFilestatSetTimes = (1 << 20),

    /// The right to invoke `.fdFilestatGet`.
    fdFilestatGet = (1 << 21),

    /// The right to invoke `.fdFilestatSetSize`.
    fdFilestatSetSize = (1 << 22),

    /// The right to invoke `.fdFilestatSetTimes`.
    fdFilestatSetTimes = (1 << 23),

    /// The right to invoke `.pathSymlink`.
    pathSymlink = (1 << 24),

    /// The right to invoke `.pathRemoveDirectory`.
    pathRemoveDirectory = (1 << 25),

    /// The right to invoke `.pathUnlinkFile`.
    pathUnlinkFile = (1 << 26),

    /**
     * If `Rights.fdRead` is set, includes the right to invoke `.pollOnOff`
     * to subscribe to `EventType.fdRead`.
     * If `Rights.fdWrite` is set, includes the right to invoke `.pollOneoff`
     * to subscribe to `EventType.fdWrite`.
     */
    pollFdReadwrite = (1 << 27),

    /// The right to invoke `.sockShutdown`.
    sockShutdown = (1 << 28),

    /// The right to invoke `.sockAccept`.
    sockAccept = (1 << 29),
}

/// A file descriptor handle.
alias Fd = int;

/// A region of memory for scatter/gather reads.
extern(C) struct IOVec {
    ubyte* buf;
    size_t bufLen;
}

/// A region of memory for scatter/gather writes.
extern(C) struct CIOVec {
    const(ubyte)* buf;
    size_t bufLen;
}

///
alias IOVecArray = IOVec[];

///
alias CIOVecArray = CIOVec[];

/// Relative offset within a file.
alias FileDelta = long;

/// The position relative to which to set the offset of the file descriptor.
enum Whence : ubyte {
    /// Seek relative to start-of-file.
    set,

    /// Seek relative to current position.
    cur,

    /// Seek relative to end-of-file.
    end
}

/// A reference to the offset of a directory entry.
alias DirCookie = ulong;
enum DirCookie DIRCOOKIE_START = 0;

/// File serial number that is unique within its file system.
alias Inode = ulong;

/// The type of a file descriptor or file.
enum FileType : ubyte {
    /// The type of the file descriptor or file is unknown or
    /// is different from any of the other types specified.
    unknown,

    /// The file descriptor or file refers to a block device inode.
    blockDevice,

    /// The file descriptor or file refers to a character device inode.
    characterDevice,

    /// The file descriptor or file refers to a directory inode.
    directory,

    /// The file descriptor or file refers to a regular file inode.
    regularFile,

    /// The file descriptor or file refers to a datagram socket.
    socketDgram,

    /// The file descriptor or file refers to a byte-stream socket.
    socketStream,

    /// The file refers to a symbolic link inode.
    symbolicLink,
}

/// A directory entry.
extern(C) struct DirEnt {
    /// The offset of the next directory entry stored in this directory.
    DirCookie next;

    /// The serial number of the file referred to by this directory entry.
    Inode inode;

    /// The length of the name of the directory entry.
    uint nameLength;

    /// The type of the file referred to by this directory entry.
    FileType type;
}

/// File or memory access pattern advisory information.
enum Advice : ubyte {
    /// The application has no advice to give on its behavior
    /// with respect to the specified data.
    normal,

    /// The application expects to access the specified data sequentially
    /// from lower offsets to higher offsets.
    sequential,

    /// The application expects to access the specified data
    /// in a random order.
    random,

    /// The application expects to access the specified data
    /// in the near future.
    willNeed,

    /// The application expects that it will not access the specified data
    /// in the near future.
    dontNeed,

    /// The application expects to access the specified data once
    /// and then not reuse it thereafter.
    noReuse,
}

/// File descriptor flags.
enum FdFlags : ushort {
    /// Append mode: Data written to the file is always appended
    /// to the file's end.
    append = (1 << 0),

    /**
     * Write according to synchronized I/O data integrity completion.
     * Only the data stored in the file is synchronized.
     *
     * This feature is not available on all platforms and therefore
     * `.pathOpen` and other such functions which accept `FdFlags` may return
     * `Errno.notsup` in the case that this flag is set.
     */
    dsync = (1 << 1),

    /// Non-blocking mode.
    nonBlock = (1 << 2),

    /**
     * Synchronized read I/O operations.
     *
     * This feature is not available on all platforms and therefore
     * `.pathOpen` and other such functions which accept `FdFlags` may return
     * `Errno.notsup` in the case that this flag is set.
     */
    rsync = (1 << 3),

    /**
     * Write according to synchronized I/O file integrity completion.
     * In addition to synchronizing the data stored in the file,
     * the implementation may also synchronously update the file's metadata.
     *
     * This feature is not available on all platforms and therefore
     * `.pathOpen` and other such functions which accept `FdFlags` may return
     * `Errno.notsup` in the case that this flag is set.
     */
    sync = (1 << 4),
}

/// File descriptor attributes.
extern(C) struct FdStat {
    /// File type.
    FileType fileType;

    /// File descriptor flags.
    FdFlags flags;

    /// Rights that apply to this file descriptor.
    Rights rightsBase;

    /// Maximum set of rights that may be installed on new file descriptors that
    /// are created through this file descriptor, e.g., through `.pathOpen`.
    Rights rightsInheriting;
}

/**
 * Identifier for a device containing a file system. Can be used in
 * combination with `Inode` to uniquely identify a file or directory.
 */
alias Device = ulong;

/// Which file time attributes to adjust.
enum FstFlags : ushort {
    /// Adjust the last data access timestamp to
    /// the value stored in `FileStat.accessTime`.
    accessTime = (1 << 0),

    /// Adjust the last data access timestamp to
    /// the time of clock `ClockID.realtime`.
    accessTimeNow = (1 << 1),

    /// Adjust the last data modification timestamp to
    /// the value stored in `FileStat.modifyTime`.
    modifyTime = (1 << 2),

    /// Adjust the last data modification timestamp to
    /// the time of clock `ClockID.realtime`.
    modifyTimeNow = (1 << 3)
}

/// Flags determining the method of how paths are resolved.
enum LookupFlags : uint {
    /// As long as the resolved path corresponds to a symbolic link,
    /// it is expanded.
    symlinkFollow = (1 << 0)
}

/// Open flags used by `pathOpen`.
enum OFlags : ushort {
    /// Create file if it does not exist.
    create = (1 << 0),

    /// Fail if not a directory.
    directory = (1 << 1),

    /// Fail if file already exists.
    exclusive = (1 << 2),

    /// Truncate file to size 0.
    truncate = (1 << 3),
}

/// Number of hard links to an inode.
alias LinkCount = ulong;

/// File attributes.
extern(C) struct FileStat {
    /// Device ID of device containing the file.
    Device device;

    /// File serial number.
    Inode inode;

    /// File type.
    FileType fileType;

    /// Number of hard links to the file.
    LinkCount nLink;

    /// For regular files, the file size in bytes. For symbolic links, the
    /// length in bytes of the pathname contained in the symbolic link.
    FileSize size;

    /// Last data access timestamp.
    Timestamp accessTime;

    /// Last data modification timestamp.
    Timestamp modifyTime;

    /// Last file status change timestamp.
    Timestamp changeTime;
}

/// User-provided value that may be attached to objects that is retained when
/// extracted from the implementation.
alias UserData = ulong;

/// Type of a subscription to an event or its occurrence.
enum EventType : ubyte {
    /// The time value of clock `SubscriptionClock.id` has reached
    /// timestamp `SubscriptionClock.timeout`
    clock,

    /// File descriptor `SubscriptionFdReadwrite.fileDescriptor` has data
    // available for reading. This event always triggers for regular files.
    fdRead,

    /// File descriptor `SubscriptionFdReadwrite.fileDescriptor` has capacity
    /// available for writing. This event always triggers for regular files.
    fdWrite
}

/// The state of the file descriptor subscribed to
/// with `EventType.fdRead` or `EventType.fdWrite`
enum EventRWFlags : ushort {
    /// The peer of this socket has closed or disconnected.
    fdReadwriteHangup = (1 << 0)
}

/// The contents of an event when type
/// is `EventType.fdRead` or `EventType.fdWrite`
extern(C) struct EventFdReadwrite {
    /// The number of bytes available for reading or writing.
    FileSize nBytes;

    /// The state of the file descriptor.
    EventRWFlags flags;
}

/// An event that occurred.
extern(C) struct Event {
    /// User-provided value that got attached to `Subscription.userData`
    UserData userData;

    /// If non-zero, an error that occurred while processing
    /// the subscription request.
    Errno error;

    /// The type of event that occurred.
    EventType type;

    /// The contents of the event if it
    /// is `EventType.fdRead` or `EventType.fdWrite`.
    EventFdReadwrite fdReadwrite;
}

/// Flags determining how to interpret the timestamp
/// provided in `SubscriptionClock.timeout`
enum SubClockFlags : ushort {
     subscriptionClockAbstime = (1 << 0)
}

/// The contents of a subscription when type is `EventType.clock`.
extern(C) struct SubscriptionClock {
    /// The clock against which to compare the timestamp.
    ClockID id;

    /// The absolute or relative timestamp.
    Timestamp timeout;

    /// The amount of time that the implementation may wait additionally
    /// to coalesce with other events.
    Timestamp precision;

    /// Flags specifying whether the timeout is absolute or relative
    SubClockFlags flags;
}

/// The contents of a subscription when type
/// is `EventType.fdRead` or `EventType.fdWrite`.
extern(C) struct SubscriptionFdReadwrite {
    Fd fileDescriptor;
}

/// The contents of a subscription.
extern(C) struct SubscriptionU {
    enum Tag : ubyte {
        clock,
        fdRead,
        fdWrite
    }

    Tag tag;
    union {
        SubscriptionClock clock;
        SubscriptionFdReadwrite fdRead;
        SubscriptionFdReadwrite fdWrite;
    }
}

/// Subscription to an event.
extern(C) struct Subscription {
    /// User-provided value that is attached to the subscription in the
    /// implementation and returned through `Event.userData`.
    UserData userData;

    /// The type of the event to which to subscribe, and its contents
    SubscriptionU u;
}

/// Exit code generated by a process when exiting.
alias ExitCode = uint;

/// Signal condition.
enum Signal : ubyte {
    /// No signal. Note that POSIX has special semantics for `kill(pid, 0)`,
    /// so this value is reserved.
    none,

    /// Hangup. Action: Terminates the process.
    hup,

    /// Terminate interrupt signal. Action: Terminates the process.
    int_,

    /// Terminal quit signal. Action: Terminates the process.
    quit,

    /// Illegal instruction. Action: Terminates the process.
    ill,

    /// Trace/breakpoint trap. Action: Terminates the process.
    trap,

    /// Process abort signal. Action: Terminates the process.
    abrt,

    /// Access to an undefined portion of memory. Action: Terminates.
    bus,

    /// Erroneous arithmetic operation. Action: Terminates the process.
    fpe,

    /// Kill. Action: Terminates the process.
    kill,

    /// User-defined signal 1. Action: Terminates the process.
    usr1,

    /// Invalid memory reference. Action: Terminates the process.
    segv,

    /// User-defined signal 2. Action: Terminates the process.
    usr2,

    /// Write on a pipe with no one to read it. Action: Ignored.
    pipe,

    /// Alarm clock. Action: Terminates the process.
    alrm,

    /// Termination signal. Action: Terminates the process.
    term,

    /// Child process terminated, stopped, or continued. Action: Ignored.
    chld,

    /// Continue executing, if stopped. Action: Continues executing,
    // if stopped.
    cont,

    /// Stop executing. Action: Stops executing.
    stop,

    /// Terminal stop signal. Action: Stops executing.
    tstp,

    /// Background process attempting read. Action: Stops executing.
    ttin,

    /// Background process attempting write. Action: Stops executing.
    ttou,

    /// High bandwidth data is available at a socket. Action: Ignored.
    urg,

    /// CPU time limit exceeded. Action: Terminates the process.
    xcpu,

    /// File size limit exceeded. Action: Terminates the process.
    xfsz,

    /// Virtual timer expired. Action: Terminates the process.
    vtalrm,

    /// Profiling timer expired. Action: Terminates the process.
    prof,

    /// Window changed. Action: Ignored.
    winch,

    /// I/O possible. Action: Terminates the process.
    poll,

    /// Power failure. Action: Terminates the process.
    pwr,

    /// Bad system call. Action: Terminates the process.
    sys,
}

/// Flags provided to `sockRecv`.
enum RiFlags : ushort {
    /// Returns the message without removing it from
    /// the socket's receive queue.
    peek = (1 << 0),

    /// On byte-stream sockets, block until the full amount
    /// of data can be returned.
    waitAll = (1 << 1)
}

/// Flags returned by `sockRecv`.
enum RoFlags : ushort {
    /// Returned by sock_recv: Message data has been truncated.
    dataTruncated = (1 << 0),
}

/// Flags provided to sock_send.
/// As there are currently no flags defined, it must be set to zero.
enum SiFlags : ushort {
    /// Zero
    none = 0,
}

/// Which channels on a socket to shut down.
enum SdFlags : ubyte {
    /// Disables further receive operations.
    rd = (1 << 0),

    /// Disables further send operations.
    wr = (1 << 1),
}

enum PreopenType : ubyte {
    /// A pre-opened directory.
    dir
}

/// The contents of a `Prestat` when type is `PreopenType.dir`.
extern(C) struct PrestatDir {
    /// The length of the directory name for use with `fdPrestatDirName`.
    size_t nameLength;
}

/// Information about a pre-opened capability.
extern(C) struct Prestat {
    enum Tag : ubyte {
        dir
    }

    Tag tag;
    union {
        PrestatDir dir;
    }
}

/// Read command-line argument data. The size of the array should match that
/// returned by `argsSizesGet`. Each argument is expected to be `\0` terminated.
Errno argsGet(ubyte** argv, ubyte* argvBuf) {
    return cast(Errno)imported_argsGet(cast(int)argv, cast(int)argvBuf);
}
@wasiImport!("args_get")
pragma(mangle, "__imported_wasi_snapshot_preview1_args_get")
extern(C) private int imported_argsGet(int, int);

/// Return command-line argument data sizes.
Errno argsSizesGet(out size_t argvSize, out size_t argvBufSize) {
    return cast(Errno)imported_argsSizesGet(cast(int)&argvSize, cast(int)&argvBufSize);
}
@wasiImport!("args_sizes_get")
pragma(mangle, "__imported_wasi_snapshot_preview1_args_sizes_get")
extern(C) private int imported_argsSizesGet(int, int);

/**
 * Read environment variable data. The sizes of the buffers should match
 * that returned by `environSizesGet`. Key/value pairs are expected to be
 * joined with `=`s, and terminated with `\0`s.
 */
Errno environGet(ubyte** environ, ubyte* environBuf) {
    return cast(Errno)imported_environGet(cast(int)environ, cast(int)environBuf);
}
@wasiImport!("environ_get")
pragma(mangle, "__imported_wasi_snapshot_preview1_environ_get")
extern(C) private int imported_environGet(int, int);

/// Return environment variable data sizes.
Errno environSizesGet(out size_t environSize, out size_t environBufSize) {
    return cast(Errno)imported_environSizesGet(
        cast(int)&environSize,
        cast(int)&environBufSize
    );
}
@wasiImport!("environ_sizes_get")
pragma(mangle, "__imported_wasi_snapshot_preview1_environ_sizes_get")
extern(C) private int imported_environSizesGet(int, int);

/**
 * Return the resolution of a clock. Implementations are required to provide
 * a non-zero value for supported clocks. For unsupported clocks, return
 * `Errno.inval`.
 *
 * Note:
 *   This is similar to `clock_getres` in POSIX.
 */
Errno clockResGet(ClockID id, out Timestamp resolution) {
    return cast(Errno)imported_clockResGet(cast(int)id, cast(int)&resolution);
}
@wasiImport!("clock_res_get")
pragma(mangle, "__imported_wasi_snapshot_preview1_clock_res_get")
extern(C) private int imported_clockResGet(int, int);

/**
 * Return the time value of a clock.
 *
 * Note:
 *   This is similar to `clock_gettime` in POSIX.
 */
Errno clockTimeGet(ClockID id, Timestamp precision, out Timestamp time) {
    return cast(Errno)imported_clockTimeGet(
        cast(int)id,
        cast(long)precision,
        cast(int)&time
    );
}
@wasiImport!("clock_time_get")
pragma(mangle, "__imported_wasi_snapshot_preview1_clock_time_get")
extern(C) private int imported_clockTimeGet(int, long, int);

/**
 * Provide file advisory information on a file descriptor.
 *
 * Note:
 *   This is similar to `posix_fadvise` in POSIX.
 */
Errno fdAdvise(Fd fd, FileSize offset, FileSize len, Advice advice) {
    return cast(Errno)imported_fdAdvise(
        cast(int)fd,
        cast(long)offset,
        cast(long)len,
        cast(int)advice
    );
}
@wasiImport!("fd_advise")
pragma(mangle, "__imported_wasi_snapshot_preview1_fd_advise")
extern(C) private int imported_fdAdvise(int, long, long, int);

/**
 * Force the allocation of space in a file.
 *
 * Note:
 *   This is similar to `posix_fallocate` in POSIX.
 */
Errno fdAllocate(Fd fd, FileSize offset, FileSize len) {
    return cast(Errno)imported_fdAllocate(cast(int)fd, cast(long)offset, cast(long)len);
}
@wasiImport!("fd_allocate")
pragma(mangle, "__imported_wasi_snapshot_preview1_fd_allocate")
extern(C) private int imported_fdAllocate(int, long, long);

/**
 * Close a file descriptor.
 *
 * Note:
 *   This is similar to `close` in POSIX.
 */
Errno fdClose(Fd fd) {
    return cast(Errno)imported_fdClose(cast(int)fd);
}
@wasiImport!("fd_close")
pragma(mangle, "__imported_wasi_snapshot_preview1_fd_close")
extern(C) private int imported_fdClose(int);

/**
 * Synchronize the data of a file to disk.
 *
 * Note:
 *   This is similar to `fdatasync` in POSIX.
 */
Errno fdDataSync(Fd fd) {
    return cast(Errno)imported_fdDataSync(cast(int)fd);
}
@wasiImport!("fd_datasync")
pragma(mangle, "__imported_wasi_snapshot_preview1_fd_datasync")
extern(C) private int imported_fdDataSync(int);

/**
 * Get the attributes of a file descriptor.
 *
 * Note:
 *   This returns similar flags to `fcntl(fd, F_GETFL)` in POSIX, as well as
 *   additional fields.
 */
Errno fdFdstatGet(Fd fd, out FdStat stat) {
    return cast(Errno)imported_fdFdstatGet(cast(int)fd, cast(int)&stat);
}
@wasiImport!("fd_fdstat_get")
pragma(mangle, "__imported_wasi_snapshot_preview1_fd_fdstat_get")
extern(C) private int imported_fdFdstatGet(int, int);

/**
 * Adjust the flags associated with a file descriptor.
 *
 * Note:
 *   This is similar to `fcntl(fd, F_SETFL, flags)` in POSIX.
 */
Errno fdFdstatSetFlags(Fd fd, FdFlags flags) {
    return cast(Errno)imported_fdFdstatSetFlags(cast(int)fd, cast(int)flags);
}
@wasiImport!("fd_fdstat_set_flags")
pragma(mangle, "__imported_wasi_snapshot_preview1_fd_fdstat_set_flags")
extern(C) private int imported_fdFdstatSetFlags(int, int);

/**
 * Adjust the rights associated with a file descriptor. This can only be used
 * to remove rights, and returns `Errno.notcapable` if called in a way that
 * would attempt to add rights.
 */
Errno fdFdstatSetRights(Fd fd, Rights rightsBase, Rights rightsInheriting) {
    return cast(Errno)imported_fdFdstatSetRights(
        cast(int)fd,
        cast(long)rightsBase,
        cast(long)rightsInheriting
    );
}
@wasiImport!("fd_fdstat_set_rights")
pragma(mangle, "__imported_wasi_snapshot_preview1_fd_fdstat_set_rights")
extern(C) private int imported_fdFdstatSetRights(int, long, long);

/// Return the attributes of an open file.
Errno fdFilestatGet(Fd fd, out FileStat stat) {
    return cast(Errno)imported_fdFilestatGet(cast(int)fd, cast(int)&stat);
}
@wasiImport!("fd_filestat_get")
pragma(mangle, "__imported_wasi_snapshot_preview1_fd_filestat_get")
extern(C) private int imported_fdFilestatGet(int, int);

/**
 * Adjust the size of an open file. If this increases the file's size, the
 * extra bytes are filled with zeros.
 *
 * Note:
 *   This is similar to `ftruncate` in POSIX.
 */
Errno fdFilestatSetSize(Fd fd, FileSize size) {
    return cast(Errno)imported_fdFilestatSetSize(cast(int)fd, cast(long)size);
}
@wasiImport!("fd_filestat_set_size")
pragma(mangle, "__imported_wasi_snapshot_preview1_fd_filestat_set_size")
extern(C) private int imported_fdFilestatSetSize(int, long);

/**
 * Adjust the timestamps of an open file or directory.
 *
 * Note:
 *   This is similar to `futimens` in POSIX.
 */
Errno fdFilestatSetTimes(
    Fd fd,
    Timestamp accessTime,
    Timestamp modifyTime,
    FstFlags fstFlags
) {
    return cast(Errno)imported_fdFilestatSetTimes(
        cast(int)fd,
        cast(long)accessTime,
        cast(long)modifyTime,
        cast(int)fstFlags
    );
}
@wasiImport!("fd_filestat_set_times")
pragma(mangle, "__imported_wasi_snapshot_preview1_fd_filestat_set_times")
extern(C) private int imported_fdFilestatSetTimes(int, long, long, int);

/**
 * Read from a file descriptor, without using and updating
 * the file descriptor's offset.
 *
 * Note:
 *   This is similar to `preadv` in Linux (and other Unix-es).
 */
Errno fdPread(Fd fd, IOVecArray iovs, FileSize offset, out size_t bytesRead) {
    return cast(Errno)imported_fdPread(
        cast(int)fd,
        cast(int)iovs.ptr,
        cast(int)iovs.length,
        cast(long)offset,
        cast(int)&bytesRead
    );
}
@wasiImport!("fd_pread")
pragma(mangle, "__imported_wasi_snapshot_preview1_fd_pread")
extern(C) private int imported_fdPread(int, int, int, long, int);

/// Return a description of the given preopened file descriptor.
Errno fdPrestatGet(Fd fd, out Prestat prestat) {
    return cast(Errno)imported_fdPrestatGet(cast(int)fd, cast(int)&prestat);
}
@wasiImport!("fd_prestat_get")
pragma(mangle, "__imported_wasi_snapshot_preview1_fd_prestat_get")
extern(C) private int imported_fdPrestatGet(int, int);

/// Return a description of the given preopened file descriptor.
Errno fdPrestatDirName(Fd fd, char[] path) {
    return cast(Errno)imported_fdPrestatDirName(
        cast(int)fd,
        cast(int)path.ptr,
        cast(int)path.length
    );
}
@wasiImport!("fd_prestat_dir_name")
pragma(mangle, "__imported_wasi_snapshot_preview1_fd_prestat_dir_name")
extern(C) private int imported_fdPrestatDirName(int, int, int);

/**
 * Write to a file descriptor, without using and updating the file descriptor's
 * offset.
 *
 * Like Linux (and other Unix-es), any calls of `fdPwrite` (and other functions
 * to read or write) for a regular file by other threads in the WASI process
 * should not be interleaved while `fdPwrite` is executed.
 *
 * Note:
 *   This is similar to `pwritev` in Linux (and other Unix-es).
 */
Errno fdPwrite(
    Fd fd,
    CIOVecArray iovs,
    FileSize offset,
    out size_t bytesWritten
) {
    return cast(Errno)imported_fdPwrite(
        cast(int)fd,
        cast(int)iovs.ptr,
        cast(int)iovs.length,
        cast(long)offset,
        cast(int)&bytesWritten
    );
}
@wasiImport!("fd_pwrite")
pragma(mangle, "__imported_wasi_snapshot_preview1_fd_pwrite")
extern(C) private int imported_fdPwrite(int, int, int, long, int);

/**
 * Read from a file descriptor.
 *
 * Note:
 *   This is similar to `readv` in POSIX.
 */
Errno fdRead(Fd fd, IOVecArray iovs, out size_t bytesRead) {
    return cast(Errno)imported_fdRead(
        cast(int)fd,
        cast(int)iovs.ptr,
        cast(int)iovs.length,
        cast(int)&bytesRead
    );
}
@wasiImport!("fd_read")
pragma(mangle, "__imported_wasi_snapshot_preview1_fd_read")
extern(C) private int imported_fdRead(int, int, int, int);

/**
 * Read directory entries from a directory. When successful, the contents of
 * the output buffer consist of a sequence of directory entries. Each directory
 * entry consists of a `DirEnt` object, followed by `DirEnt.nameLength` bytes
 * holding the name of the directory entry. This function fills the output
 * buffer as much as possible, potentially truncating the last directory entry.
 * This allows the caller to grow its read buffer size in case it's too small
 * to fit a single large directory entry, or skip the oversized directory
 * entry.
 */
Errno fdReadDir(Fd fd, ubyte[] buf, DirCookie cookie, out size_t bytesRead) {
    return cast(Errno)imported_fdReadDir(
        cast(int)fd,
        cast(int)buf.ptr,
        cast(int)buf.length,
        cast(long)cookie,
        cast(int)&bytesRead
    );
}
@wasiImport!("fd_readdir")
pragma(mangle, "__imported_wasi_snapshot_preview1_fd_readdir")
extern(C) private int imported_fdReadDir(int, int, int, long, int);

/**
 * Atomically replace a file descriptor by renumbering another file descriptor.
 * Due to the strong focus on thread safety, this environment does not provide
 * a mechanism to duplicate or renumber a file descriptor to an arbitrary
 * number, like dup2(). This would be prone to race conditions, as an actual
 * file descriptor with the same number could be allocated by a different
 * thread at the same time. This function provides a way to atomically renumber
 * file descriptors, which would disappear if dup2() were to be removed
 * entirely.
 */
Errno fdRenumber(Fd fd, Fd to) {
    return cast(Errno)imported_fdRenumber(cast(int)fd, cast(int)to);
}
@wasiImport!("fd_renumber")
pragma(mangle, "__imported_wasi_snapshot_preview1_fd_renumber")
extern(C) private int imported_fdRenumber(int, int);

/**
 * Move the offset of a file descriptor.
 *
 * Note:
 *   This is similar to `lseek` in POSIX.
 */
Errno fdSeek(Fd fd, FileDelta offset, Whence whence, out FileSize newOffset) {
    return cast(Errno)imported_fdSeek(
        cast(int)fd,
        cast(long)offset,
        cast(int)whence,
        cast(int)&newOffset
    );
}
@wasiImport!("fd_seek")
pragma(mangle, "__imported_wasi_snapshot_preview1_fd_seek")
extern(C) private int imported_fdSeek(int, long, int, int);

/**
 * Synchronize the data and metadata of a file to disk.
 *
 * Note:
 *   This is similar to `fsync` in POSIX.
 */
Errno fdSync(Fd fd) {
    return cast(Errno)imported_fdSync(cast(int)fd);
}
@wasiImport!("fd_sync")
pragma(mangle, "__imported_wasi_snapshot_preview1_fd_sync")
extern(C) private int imported_fdSync(int);

/**
 * Return the current offset of a file descriptor.
 *
 * Note:
 *   This is similar to `lseek(fd, 0, SEEK_CUR)` in POSIX.
 */
Errno fdTell(Fd fd, out FileSize offset) {
    return cast(Errno)imported_fdTell(cast(int)fd, cast(int)&offset);
}
@wasiImport!("fd_tell")
pragma(mangle, "__imported_wasi_snapshot_preview1_fd_tell")
extern(C) private int imported_fdTell(int, int);

/**
 * Write to a file descriptor.
 *
 * Like POSIX, any calls of `fdWrite` (and other functions to read or write)
 * for a regular file by other threads in the WASI process should not be
 * interleaved while `fdWrite` is executed.
 *
 * Note:
 *   This is similar to `writev` in POSIX.
 */
Errno fdWrite(Fd fd, CIOVecArray iovs, out size_t bytesWritten) {
    return cast(Errno)imported_fdWrite(
        cast(int)fd,
        cast(int)iovs.ptr,
        cast(int)iovs.length,
        cast(int)&bytesWritten
    );
}
@wasiImport!("fd_write")
pragma(mangle, "__imported_wasi_snapshot_preview1_fd_write")
extern(C) private int imported_fdWrite(int, int, int, int);

/**
 * Create a directory.
 *
 * Note:
 *   This is similar to `mkdirat` in POSIX.
 */
Errno pathCreateDirectory(Fd fd, const(char)[] path) {
    return cast(Errno)imported_pathCreateDirectory(
        cast(int)fd,
        cast(int)path.ptr,
        cast(int)path.length
    );
}
@wasiImport!("path_create_directory")
pragma(mangle, "__imported_wasi_snapshot_preview1_path_create_directory")
extern(C) private int imported_pathCreateDirectory(int, int, int);

/**
 * Return the attributes of a file or directory.
 *
 * Note:
 *   This is similar to `stat` in POSIX.
 */
Errno pathFilestatGet(
    Fd fd,
    LookupFlags flags,
    const(char)[] path,
    out FileStat stat
) {
    return cast(Errno)imported_pathFilestatGet(
        cast(int)fd,
        cast(int)flags,
        cast(int)path.ptr,
        cast(int)path.length,
        cast(int)&stat
    );
}
@wasiImport!("path_filestat_get")
pragma(mangle, "__imported_wasi_snapshot_preview1_path_filestat_get")
extern(C) private int imported_pathFilestatGet(int, int, int, int, int);

/**
 * Adjust the timestamps of a file or directory.
 *
 * Note:
 *   This is similar to `utimensat` in POSIX.
 */
Errno pathFilestatSetTimes(
    Fd fd,
    LookupFlags flags,
    const(char)[] path,
    Timestamp accessTime,
    Timestamp modifyTime,
    FstFlags fstFlags
) {
    return cast(Errno)imported_pathFilestatSetTimes(
        cast(int)fd,
        cast(int)flags,
        cast(int)path.ptr,
        cast(int)path.length,
        cast(long)accessTime,
        cast(long)modifyTime,
        cast(int)fstFlags
    );
}
@wasiImport!("path_filestat_set_times")
pragma(mangle, "__imported_wasi_snapshot_preview1_path_filestat_set_times")
extern(C) private int imported_pathFilestatSetTimes(int, int, int, int, long, long, int);

/**
 * Create a hard link.
 *
 * Note:
 *   This is similar to `linkat` in POSIX.
 */
Errno pathLink(
    Fd oldFd,
    LookupFlags oldFlags,
    const(char)[] oldPath,
    Fd newFd,
    const(char)[] newPath
) {
    return cast(Errno)imported_pathLink(
        cast(int)oldFd,
        cast(int)oldFlags,
        cast(int)oldPath.ptr,
        cast(int)oldPath.length,
        cast(int)newFd,
        cast(int)newPath.ptr,
        cast(int)newPath.length
    );
}
@wasiImport!("path_link")
pragma(mangle, "__imported_wasi_snapshot_preview1_path_link")
extern(C) private int imported_pathLink(int, int, int, int, int, int, int);

/**
 * Open a file or directory. The returned file descriptor is not guaranteed to
 * be the lowest-numbered file descriptor not currently open; it is randomized
 * to prevent applications from depending on making assumptions about indexes,
 * since this is error-prone in multi-threaded contexts. The returned file
 * descriptor is guaranteed to be less than 2**31.
 *
 * Note:
 *   This is similar to `openat` in POSIX.
 */
Errno pathOpen(
    Fd fd,
    LookupFlags dirFlags,
    const(char)[] path,
    OFlags oFlags,
    Rights rightsBase,
    Rights rightsInheriting,
    FdFlags fdFlags,
    out Fd openedFd
) {
    return cast(Errno)imported_pathOpen(
        cast(int)fd,
        cast(int)dirFlags,
        cast(int)path.ptr,
        cast(int)path.length,
        cast(int)oFlags,
        cast(long)rightsBase,
        cast(long)rightsInheriting,
        cast(int)fdFlags,
        cast(int)&openedFd
    );
}
@wasiImport!("path_open")
pragma(mangle, "__imported_wasi_snapshot_preview1_path_open")
extern(C) private int imported_pathOpen(int, int, int, int, int, long, long, int, int);

/**
 * Read the contents of a symbolic link.
 *
 * Note:
 *   This is similar to `readlinkat` in POSIX.
 */
Errno pathReadlink(Fd fd, const(char)[] path, ubyte[] buf, out size_t bytesRead) {
    return cast(Errno)imported_pathReadlink(
        cast(int)fd,
        cast(int)path.ptr,
        cast(int)path.length,
        cast(int)buf.ptr,
        cast(int)buf.length,
        cast(int)&bytesRead
    );
}
@wasiImport!("path_readlink")
pragma(mangle, "__imported_wasi_snapshot_preview1_path_readlink")
extern(C) private int imported_pathReadlink(int, int, int, int, int, int);

/**
 * Remove a directory. Return `Errno.notempty` if the directory is not empty.
 *
 * Note:
 *   This is similar to `unlinkat(fd, path, AT_REMOVEDIR)` in POSIX.
 */
Errno pathRemoveDirectory(Fd fd, const(char)[] path) {
    return cast(Errno)imported_pathRemoveDirectory(
        cast(int)fd,
        cast(int)path.ptr,
        cast(int)path.length
    );
}
@wasiImport!("path_remove_directory")
pragma(mangle, "__imported_wasi_snapshot_preview1_path_remove_directory")
extern(C) private int imported_pathRemoveDirectory(int, int, int);

/**
 * Rename a file or directory.
 *
 * Note:
 *   This is similar to `renameat` in POSIX.
 */
Errno pathRename(Fd fd, const(char)[] oldPath, Fd newFd, const(char)[] newPath) {
    return cast(Errno)imported_pathRename(
        cast(int)fd,
        cast(int)oldPath.ptr,
        cast(int)oldPath.length,
        cast(int)newFd,
        cast(int)newPath.ptr,
        cast(int)newPath.length
    );
}
@wasiImport!("path_rename")
pragma(mangle, "__imported_wasi_snapshot_preview1_path_rename")
extern(C) private int imported_pathRename(int, int, int, int, int, int);

/**
 * Create a symbolic link.
 *
 * Note:
 *   This is similar to `symlinkat` in POSIX.
 */
Errno pathSymlink(const(char)[] oldPath, Fd fd, const(char)[] newPath) {
    return cast(Errno)imported_pathSymlink(
        cast(int)oldPath.ptr,
        cast(int)oldPath.length,
        cast(int)fd,
        cast(int)newPath.ptr,
        cast(int)newPath.length
    );
}
@wasiImport!("path_symlink")
pragma(mangle, "__imported_wasi_snapshot_preview1_path_symlink")
extern(C) private int imported_pathSymlink(int, int, int, int, int);

/**
 * Unlink a file. Return `Errno.isdir` if the path refers to a directory.
 *
 * Note:
 *   This is similar to `unlinkat(fd, path, 0)` in POSIX.
 */
Errno pathUnlinkFile(Fd fd, const(char)[] path) {
    return cast(Errno)imported_pathUnlinkFile(
        cast(int)fd,
        cast(int)path.ptr,
        cast(int)path.length
    );
}
@wasiImport!("path_unlink_file")
pragma(mangle, "__imported_wasi_snapshot_preview1_path_unlink_file")
extern(C) private int imported_pathUnlinkFile(int, int, int);

/// Concurrently poll for the occurrence of a set of events.
Errno pollOneOff(
    const(Subscription)[] subscriptions,
    Event[] events,
    out size_t numEvents
) {
    assert(subscriptions.length == events.length);
    return cast(Errno)imported_pollOneOff(
        cast(int)subscriptions.ptr,
        cast(int)events.ptr,
        cast(int)subscriptions.length,
        cast(int)&numEvents
    );
}
@wasiImport!("poll_oneoff")
pragma(mangle, "__imported_wasi_snapshot_preview1_poll_oneoff")
extern(C) private int imported_pollOneOff(int, int, int, int);

/**
 * Terminate the process normally. An exit code of 0 indicates successful
 * termination of the program. The meanings of other values is dependent
 * on the environment.
 */
noreturn procExit(ExitCode rval) {
    imported_procExit(cast(int)rval);
}
@wasiImport!("proc_exit")
pragma(mangle, "__imported_wasi_snapshot_preview1_proc_exit")
extern(C) private noreturn imported_procExit(int);

/**
 * Temporarily yield execution of the calling thread.
 *
 * Note:
 *   This is similar to `sched_yield` in POSIX.
 */
Errno schedYield() {
    return cast(Errno)imported_schedYield();
}
@wasiImport!("sched_yield")
pragma(mangle, "__imported_wasi_snapshot_preview1_sched_yield")
extern(C) private int imported_schedYield();

/**
 * Write high-quality random data into a buffer. This function blocks when the
 * implementation is unable to immediately provide sufficient high-quality
 * random data.
 */
Errno randomGet(ubyte[] buf) {
    return cast(Errno)imported_randomGet(cast(int)buf.ptr, cast(int)buf.length);
}
@wasiImport!("random_get")
pragma(mangle, "__imported_wasi_snapshot_preview1_random_get")
extern(C) private int imported_randomGet(int, int);

/**
 * Accept a new incoming connection.
 *
 * Note:
 *   This is similar to `accept` in POSIX.
 */
Errno sockAccept(Fd fd, FdFlags flags, out Fd acceptedFd) {
    return cast(Errno)imported_sockAccept(cast(int)fd, cast(int)flags, cast(int)&acceptedFd);
}
@wasiImport!("sock_accept")
pragma(mangle, "__imported_wasi_snapshot_preview1_sock_accept")
extern(C) private int imported_sockAccept(int, int, int);

/**
 * Receive a message from a socket.
 *
 * Note:
 *   This is similar to `recv` in POSIX, though it also supports reading the
 *   data into multiple buffers in the manner of `readv`.
 */
Errno sockRecv(
    Fd fd,
    IOVecArray riData,
    RiFlags riFlags,
    out size_t bytesReceived,
    out RoFlags roFlags
) {
    return cast(Errno)imported_sockRecv(
        cast(int)fd,
        cast(int)riData.ptr,
        cast(int)riData.length,
        cast(int)riFlags,
        cast(int)&bytesReceived,
        cast(int)&roFlags
    );
}
@wasiImport!("sock_recv")
pragma(mangle, "__imported_wasi_snapshot_preview1_sock_recv")
extern(C) private int imported_sockRecv(int, int, int, int, int, int);

/**
 * Send a message on a socket.
 *
 * Note:
 *   This is similar to `send` in POSIX, though it also supports writing the
 *   data from multiple buffers in the manner of `writev`.
 */
Errno sockSend(
    Fd fd,
    CIOVecArray siData,
    SiFlags siFlags,
    out size_t bytesSent
) {
    return cast(Errno)imported_sockSend(
        cast(int)fd,
        cast(int)siData.ptr,
        cast(int)siData.length,
        cast(int)siFlags,
        cast(int)&bytesSent
    );
}
@wasiImport!("sock_send")
pragma(mangle, "__imported_wasi_snapshot_preview1_sock_send")
extern(C) private int imported_sockSend(int, int, int, int, int);

/**
 * Shut down socket send and receive channels.
 *
 * Note:
 *   This is similar to `shutdown` in POSIX.
 */
Errno sockShutdown(Fd fd, SdFlags how) {
    return cast(Errno)imported_sockShutdown(cast(int)fd, cast(int)how);
}
@wasiImport!("sock_shutdown")
pragma(mangle, "__imported_wasi_snapshot_preview1_sock_shutdown")
extern(C) private int imported_sockShutdown(int, int);
