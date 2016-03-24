/**
 * Helpers for determining TLS memory ranges on OS X.
 *
 * This unfortunately cannot be entirely done in D, as the OS X API uses
 * the Apple-specific blocks C extension.
 *
 * Copyright: David Nadlinger, 2012.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   David Nadlinger
 */

#ifndef __APPLE__
#ifndef __BLOCKS__
 #error "Need a C compiler with Apple Blocks support – not building on OS X with Clang?"
#endif
#endif

#include <assert.h>
#include <stddef.h>
#include <stdio.h>

/*
 * Declarations from dyld_priv.h, available on 10.7+.
 */
enum dyld_tlv_states {
    dyld_tlv_state_allocated = 10,
    dyld_tlv_state_deallocated = 20
};
typedef struct {
    size_t info_size;
    void * tlv_addr;
    size_t tlv_size;
} dyld_tlv_info;
typedef void (^dyld_tlv_state_change_handler)(enum dyld_tlv_states state, const dyld_tlv_info *info);
extern void dyld_register_tlv_state_change_handler(enum dyld_tlv_states state, dyld_tlv_state_change_handler handler);
extern void dyld_enumerate_tlv_storage(dyld_tlv_state_change_handler handler);

void _d_dyld_getTLSRange(void* arbitraryTLSSymbol, void** start, size_t* size) {
    dyld_enumerate_tlv_storage(
        ^(enum dyld_tlv_states state, const dyld_tlv_info *info) {
            assert(state == dyld_tlv_state_allocated);
            if (info->tlv_addr <= arbitraryTLSSymbol &&
                arbitraryTLSSymbol < (info->tlv_addr + info->tlv_size)
            ) {
                // Found the range.
                *start = info->tlv_addr;
                *size = info->tlv_size;
            }
        }
    );
}
