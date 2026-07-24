/++

+/
module core.sys.wasi.p2.clocks.wall_clock.common;

import core.sys.wasi.wit_common;


package (core.sys.wasi.p2) void __wit_bindgen_component_type_force_link() pure @nogc nothrow => imported!"core.sys.wasi.p2.cli.imports".__wit_bindgen_component_type_force_link();

/++

+/
struct Datetime {
  /++

  +/
  ulong seconds;

  /++

  +/
  uint nanoseconds;

  void witFree() @nogc nothrow {
  }

  Datetime witClone() const @nogc nothrow {
    Datetime clone = void;
    clone.seconds = this.seconds.witClone;
    clone.nanoseconds = this.nanoseconds.witClone;
    return clone;
  }
}
