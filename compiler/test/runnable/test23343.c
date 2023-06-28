/* DISABLED: win32 win64 linux32 linux64 freebsd32 freebsd64 osx32 dragonflybsd32 netbsd32
 */

/* https://issues.dlang.org/show_bug.cgi?id=23343
 */

int open(const char*, int, ...) asm("_" "open");

int main(){
    int fd = open("/dev/null", 0);
    return fd >= 0 ? 0 : 1;
}
