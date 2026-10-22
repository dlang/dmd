/**
 * This module declares intrinsics for WebAssembly instructions.
 *
 * Calls to these functions are recognized by the compiler when targeting
 * WebAssembly and lowered to the corresponding instruction.
 *
 * Copyright: Copyright © 2026, The D Language Foundation
 * License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Authors:   Dennis Korpel
 * Source:    $(DRUNTIMESRC core/wasm.d)
 */

module core.wasm;

version (WebAssembly):

nothrow:
@safe:
@nogc:

/*************************************
 * The `memory.grow` instruction: grow linear memory by `pages` 64 KiB pages.
 *
 * Params:
 *      pages = number of 64 KiB pages to grow linear memory by
 * Returns:
 *      the previous size of linear memory in pages, or -1 if it could not grow
 */
int memoryGrow(int pages);

/*************************************
 * The `memory.size` instruction.
 *
 * Returns:
 *      the current size of linear memory in 64 KiB pages
 */
int memorySize();
