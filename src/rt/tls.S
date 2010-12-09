/**
 * Contains support code for thread-local storage.
 *
 * Copyright: Copyright Digital Mars 2008 - 2010.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Walter Bright
 */

/*          Copyright Digital Mars 2008 - 2010.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
#if linux

/* The memory between the addresses of _tlsstart and _tlsend is the storage for
 * thread-local data in D 2.0.  Both of these rely on the default linker script
 * of:
 *      .tdata : { *(.tdata .tdata.* .gnu.linkonce.td.*) }
 *      .tbss  : { *(.tbss .tbss.* .gnu.linkonce.tb.*) *(.tcommon) }
 * to group the sections in that order.
 *
 * Sadly, this does not work because ld orders .tdata after .tdata.*, despite
 * what the linker script says.
 */

.file "tls.S"

.globl _tlsstart
    .section .tdata,"awT",@progbits
    .align 4
    .type   _tlsstart, @object
    .size   _tlsstart, 4
_tlsstart:
    .long   3

.globl _tlsend
    .section .tcommon,"awT",@nobits
    .align 4
    .type   _tlsend, @object
    .size   _tlsend, 4
_tlsend:
    .zero   4

#endif
