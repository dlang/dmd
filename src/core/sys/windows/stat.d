
/// Placed into public domain
/// Author: Walter Bright

module core.sys.windows.stat;
version (Windows):

extern (C) nothrow @nogc:

// linux version is in std.c.linux.linux

const S_IFMT   = 0xF000;
const S_IFDIR  = 0x4000;
const S_IFCHR  = 0x2000;
const S_IFIFO  = 0x1000;
const S_IFREG  = 0x8000;
const S_IREAD  = 0x0100;
const S_IWRITE = 0x0080;
const S_IEXEC  = 0x0040;
const S_IFBLK  = 0x6000;
const S_IFNAM  = 0x5000;

@safe pure
{
int S_ISREG(int m)  { return (m & S_IFMT) == S_IFREG; }
int S_ISBLK(int m)  { return (m & S_IFMT) == S_IFBLK; }
int S_ISNAM(int m)  { return (m & S_IFMT) == S_IFNAM; }
int S_ISDIR(int m)  { return (m & S_IFMT) == S_IFDIR; }
int S_ISCHR(int m)  { return (m & S_IFMT) == S_IFCHR; }
}

struct struct_stat
{
    short st_dev;
    ushort st_ino;
    ushort st_mode;
    short st_nlink;
    ushort st_uid;
    ushort st_gid;
    short st_rdev;
    short dummy;
    int st_size;
    int st_atime;
    int st_mtime;
    int st_ctime;
}

int  stat(char *, struct_stat *);
int  fstat(int, struct_stat *);
int  _wstat(wchar *, struct_stat *);
