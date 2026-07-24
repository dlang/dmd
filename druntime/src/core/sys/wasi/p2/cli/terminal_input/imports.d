/++
Terminal input.

In the future, this may include functions for disabling echoing,
disabling input buffering so that keyboard events are sent through
immediately, querying supported features, and so on.
+/
module core.sys.wasi.p2.cli.terminal_input.imports;

import core.sys.wasi.wit_common;

public import core.sys.wasi.p2.cli.terminal_input.common;


package (core.sys.wasi.p2) void __wit_bindgen_component_type_force_link() pure @nogc nothrow => imported!"core.sys.wasi.p2.cli.imports".__wit_bindgen_component_type_force_link();

/++
The input side of a terminal.
+/
struct TerminalInput {
  @nogc nothrow:

  package(core.sys.wasi.p2) uint __handle = 0;

  package(core.sys.wasi.p2) this(uint handle) {
    __handle = handle;
  }

  @disable this();


  void drop() {
    __import_drop(__handle);
  }
  @wasmImport!("wasi:cli/terminal-input@0.2.12", "[resource-drop]terminal-input")
  pragma(mangle, "__wit_import_wasi:cli__terminal_input@0.2.12__:resource_drop:terminal_input")
  static private extern(C) void __import_drop(uint);

  alias witFree = drop;
  // TODO: make RAII? disable copy for the own

  Borrow borrow() => Borrow(__handle);
  alias borrow this;

  struct Borrow {
    @nogc nothrow:

    package(core.sys.wasi.p2) uint __handle = 0;

    package(core.sys.wasi.p2) this(uint handle) {
      __handle = handle;
    }

    @disable this();

    void witFree() {}
    Borrow witClone() const { return Borrow(__handle); }
  }
}
