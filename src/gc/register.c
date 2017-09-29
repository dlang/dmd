/**
 * This module is used to mark the GC registration functions as C constructors.
 *
 * Copyright: Copyright Martin Nowak 2017-.
 * License:   $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   Martin Nowak
 * Source: $(DRUNTIMESRC src/gc/init.c)
 */

int _dummy_ref_to_link_gc_register_constructor; // dummy var referenced by GC so this files gets linked

extern void _d_register_conservative_gc();
extern void _d_register_manual_gc();

__attribute__ ((constructor)) static void register_gcs()
{
    _d_register_conservative_gc();
    _d_register_manual_gc();
}
