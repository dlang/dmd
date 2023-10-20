// https://issues.dlang.org/show_bug.cgi?id=22892

char buf[1];
void fn() { char c = *buf; }
