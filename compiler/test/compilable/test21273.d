// https://github.com/dlang/dmd/issues/21273
import imports.imp21273;
extern(Windows) void w();
proc p = &w;
void main(){
    p1 = &w;
    p2 = &w;
    S21273 s;
    s.p1 = &w;
    s.p2 = &w;
}
