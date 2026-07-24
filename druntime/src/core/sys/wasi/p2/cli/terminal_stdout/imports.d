/++
An interface providing an optional `terminal-output` for stdout as a
link-time authority.
+/
module core.sys.wasi.p2.cli.terminal_stdout.imports;

import core.sys.wasi.wit_common;

public import core.sys.wasi.p2.cli.terminal_stdout.common;

static import core.sys.wasi.p2.cli.terminal_output.imports;

package (core.sys.wasi.p2) void __wit_bindgen_component_type_force_link() pure @nogc nothrow => imported!"core.sys.wasi.p2.cli.imports".__wit_bindgen_component_type_force_link();

/++

+/
alias TerminalOutput = core.sys.wasi.p2.cli.terminal_output.imports.TerminalOutput;

/++
If stdout is connected to a terminal, return a `terminal-output` handle
allowing further interaction with it.
+/
Option!(TerminalOutput) getTerminalStdout() @nogc nothrow {
  align(4) void[8] _retArea = void;
  __import_getTerminalStdout(_retArea.ptr);
  Option!(TerminalOutput) _option2 = void;
  bool _isSome2 = (cast(uint)(*(cast(ubyte*)(_retArea.ptr + 0)))) != 0;
  if (_isSome2) {

    _option2 = Option!(TerminalOutput).some(TerminalOutput(*(cast(uint*)(_retArea.ptr + 4))));
  } else {
    _option2 = Option!(TerminalOutput).none;
  }
  auto _flush3 = _option2;
  return _flush3;
}
/// ditto
@wasmImport!("wasi:cli/terminal-stdout@0.2.12", "get-terminal-stdout")
pragma(mangle, "__wit_import_wasi:cli__terminal_stdout@0.2.12__get_terminal_stdout")
private extern(C) void __import_getTerminalStdout(void*) @nogc nothrow;
