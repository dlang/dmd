// EXTRA_FILES: test15389_x.d
import test15389_x;

//struct ns
extern (C++, ns)
{
    class Y { test15389_x.ns.X b; }
}
