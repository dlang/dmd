/++
An interface providing an optional `terminal-output` for stdout as a
link-time authority.
+/
module core.sys.wasi.p2.cli.terminal_stdout.common;

import core.sys.wasi.wit_common;

static import core.sys.wasi.p2.cli.terminal_output.common;

package (core.sys.wasi.p2) void __wit_bindgen_component_type_force_link() pure @nogc nothrow => imported!"core.sys.wasi.p2.cli.imports".__wit_bindgen_component_type_force_link();
