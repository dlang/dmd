/++
Terminal input.

In the future, this may include functions for disabling echoing,
disabling input buffering so that keyboard events are sent through
immediately, querying supported features, and so on.
+/
module core.sys.wasi.p2.cli.terminal_input.common;

import core.sys.wasi.wit_common;


package (core.sys.wasi.p2) void __wit_bindgen_component_type_force_link() pure @nogc nothrow => imported!"core.sys.wasi.p2.cli.imports".__wit_bindgen_component_type_force_link();
