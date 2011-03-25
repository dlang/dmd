import std.stdio, std.datetime, core.memory;

void main(string[] args) {
    enum mul = 1000;
    auto ptr = GC.malloc(mul * 1_048_576, GC.BlkAttr.NO_SCAN);

    auto sw = StopWatch(autoStart);
    GC.collect();
    immutable msec = sw.peek.msecs;
    writefln("HugeSingle:  Collected a %s megabyte heap in %s milliseconds.",
        mul, msec);
}
