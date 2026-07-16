/++
An interface providing an optional `terminal-output` for stderr as a
link-time authority.
+/
module core.sys.wasi.p2.cli.terminal_stderr.imports;

import core.sys.wasi.wit_common;

public import core.sys.wasi.p2.cli.terminal_stderr.common;

static import core.sys.wasi.p2.cli.terminal_output.imports;

package (core.sys.wasi.p2) void __wit_bindgen_component_type_force_link() pure @nogc nothrow => imported!"core.sys.wasi.p2.cli.imports".__wit_bindgen_component_type_force_link();

/++

+/
alias TerminalOutput = core.sys.wasi.p2.cli.terminal_output.imports.TerminalOutput;

/++
If stderr is connected to a terminal, return a `terminal-output` handle
allowing further interaction with it.
+/
Option!(TerminalOutput) getTerminalStderr() @nogc nothrow {
  align(4) void[8] _retArea = void;
  __import_getTerminalStderr(_retArea.ptr);
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
@wasmImport!("wasi:cli/terminal-stderr@0.2.12", "get-terminal-stderr")
pragma(mangle, "__wit_import_wasi:cli__terminal_stderr@0.2.12__get_terminal_stderr")
private extern(C) void __import_getTerminalStderr(void*) @nogc nothrow;
