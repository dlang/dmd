module core.sys.linux.fcntl;

public import core.sys.posix.fcntl;

version (linux):
extern(C):
nothrow:

// From linux/falloc.h
/// fallocate(2) params
enum {
    /// Allocates and initializes to zero the disk space
    /// within the specified range, but the file size
    /// will not be modified.
    FALLOC_FL_KEEP_SIZE = 0x01,
    /// Deallocates space (i.e. creates a hole)
    FALLOC_FL_PUNCH_HOLE = 0x02,
    /// Newly allocated blocks will be marked as initialized.
    FALLOC_FL_NO_HIDE_STALE = 0x04,
    /// Removes a byte range from a file, without leaving a hole
    FALLOC_FL_COLLAPSE_RANGE = 0x08,
    /// Zeroes space in the specified byte range
    FALLOC_FL_ZERO_RANGE = 0x10,
    /// Increases the file space by inserting a hole
    /// without overwriting any existing data
    FALLOC_FL_INSERT_RANGE = 0x20,
    /// Used to unshare shared blocks within
    /// the file size without overwriting any existing data
    FALLOC_FL_UNSHARE_RANGE = 0x40
}

// Linux-specific fallocate
// (http://man7.org/linux/man-pages/man2/fallocate.2.html)
int fallocate(int fd, int mode, off_t offset, off_t len);
