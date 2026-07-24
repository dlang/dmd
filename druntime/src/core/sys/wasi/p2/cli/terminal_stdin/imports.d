/++
An interface providing an optional `terminal-input` for stdin as a
link-time authority.
+/
module core.sys.wasi.p2.cli.terminal_stdin.imports;

import core.sys.wasi.wit_common;

public import core.sys.wasi.p2.cli.terminal_stdin.common;

static import core.sys.wasi.p2.cli.terminal_input.imports;

package (core.sys.wasi.p2) void __wit_bindgen_component_type_force_link() pure @nogc nothrow => imported!"core.sys.wasi.p2.cli.imports".__wit_bindgen_component_type_force_link();

/++

+/
alias TerminalInput = core.sys.wasi.p2.cli.terminal_input.imports.TerminalInput;

/++
If stdin is connected to a terminal, return a `terminal-input` handle
allowing further interaction with it.
+/
Option!(TerminalInput) getTerminalStdin() @nogc nothrow {
  align(4) void[8] _retArea = void;
  __import_getTerminalStdin(_retArea.ptr);
  Option!(TerminalInput) _option2 = void;
  bool _isSome2 = (cast(uint)(*(cast(ubyte*)(_retArea.ptr + 0)))) != 0;
  if (_isSome2) {

    _option2 = Option!(TerminalInput).some(TerminalInput(*(cast(uint*)(_retArea.ptr + 4))));
  } else {
    _option2 = Option!(TerminalInput).none;
  }
  auto _flush3 = _option2;
  return _flush3;
}
/// ditto
@wasmImport!("wasi:cli/terminal-stdin@0.2.12", "get-terminal-stdin")
pragma(mangle, "__wit_import_wasi:cli__terminal_stdin@0.2.12__get_terminal_stdin")
private extern(C) void __import_getTerminalStdin(void*) @nogc nothrow;
