/* The memory between the addresses of _tlsstart and _tlsend is the storage for
 * thread-local data in D 2.0.  Both of these rely on the default linker script
 * of:
 *      .tdata : { *(.tdata .tdata.* .gnu.linkonce.td.*) }
 *      .tbss  : { *(.tbss .tbss.* .gnu.linkonce.tb.*) *(.tcommon) }
 * to group the sections in that order.
 */

.file "tls.s"

.globl _tlsstart
    .section .tdata,"awT",@progbits
    .align 4
    .type   _tlsstart, @object
    .size   _tlsstart, 4
_tlsstart:
    .long   3

.globl _tlsend
    .section .tbss.end,"awT",@nobits
    .align 4
    .type   _tlsend, @object
    .size   _tlsend, 4
_tlsend:
    .zero   4
