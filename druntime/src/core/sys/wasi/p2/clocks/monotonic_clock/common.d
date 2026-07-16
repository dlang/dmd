/++

+/
module core.sys.wasi.p2.clocks.monotonic_clock.common;

import core.sys.wasi.wit_common;

static import core.sys.wasi.p2.io.poll.common;

package (core.sys.wasi.p2) void __wit_bindgen_component_type_force_link() pure @nogc nothrow => imported!"core.sys.wasi.p2.cli.imports".__wit_bindgen_component_type_force_link();

/++

+/
alias Instant = ulong;

/++

+/
alias Duration = ulong;
