module core.sys.linux.fcntl;

public import core.sys.posix.fcntl;

version (linux):
extern(C):
nothrow:

// From Linux's unistd.h, stdio.h, and linux/fs.h
enum {
    SEEK_DATA = 3,
    SEEK_HOLE = 4
}

// From linux/falloc.h
enum {
    FALLOC_FL_KEEP_SIZE = 0x01,
    FALLOC_FL_PUNCH_HOLE = 0x02,
    FALLOC_FL_NO_HIDE_STALE = 0x04
}

// Linux-specific fallocate
// (http://man7.org/linux/man-pages/man2/fallocate.2.html)
int fallocate(int fd, int mode, off_t offset, off_t len);
