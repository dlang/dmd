// EXTRA_SOURCES: extra-files/linkerlistdef.d
module linkerlist;
import linkerlistdef;

static assert(() { myInts ~= 5; return true; }());
static assert(() { my3Ints ~= [5, 6, 7]; return true; }());
static assert(() { myObjects ~= new Object; return true; }());
static assert(() { myInterfaces ~= new CI; return true; }());
static assert(() { myStructs1 ~= S(9); return true; }());
static assert(() { myStructs2 ~= new S(10); return true; }());
static assert(() { myStrings ~= __FUNCTION__; return true; }());

void main() {
    int count;

    foreach(ref v; myInts) {
        count++;
        v = typeof(v).init;
    }
    assert(count == 2);

    foreach(ref v; my3Ints) {
        count++;
        v = typeof(v).init;
    }
    assert(count == 4);

    foreach(ref v; myObjects) {
        count++;
        v = typeof(v).init;
    }
    assert(count == 6);

    foreach(ref v; myInterfaces) {
        count++;
        v = typeof(v).init;
    }
    assert(count == 8);

    foreach(ref v; myStructs1) {
        count++;
        v = typeof(v).init;
    }
    assert(count == 10);

    foreach(ref v; myStructs2) {
        count++;
        v = typeof(v).init;
    }
    assert(count == 12);

    foreach(ref v; myStrings) {
        count++;
        v = typeof(v).init;
    }
    assert(count == 14);
}
