/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1999-2019 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/storage_class.d, _storage_class.d)
 * Documentation:  https://dlang.org/phobos/dmd_storage_class.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/storage_class.d
 */

module dmd.storage_class;

/**
 * Enumerates the possible storage classes.
 *
 * Storage classes are used to gives extra information to variables (data location,
 * constness, etc.), to parameters (constness, passed by reference, etc.) and
 * to functions (safeness attribute, purity, etc).
 */
enum StorageClass : ulong
{
    undefined           = 0L,
    static_             = (1L << 0),
    extern_             = (1L << 1),
    const_              = (1L << 2),
    final_              = (1L << 3),
    abstract_           = (1L << 4),
    parameter           = (1L << 5),
    field               = (1L << 6),
    override_           = (1L << 7),
    auto_               = (1L << 8),
    synchronized_       = (1L << 9),
    deprecated_         = (1L << 10),
    in_                 = (1L << 11),   /// in parameter
    out_                = (1L << 12),   /// out parameter
    lazy_               = (1L << 13),   /// lazy parameter
    foreach_            = (1L << 14),   /// variable for foreach loop
                          //(1L << 15)
    variadic            = (1L << 16),   /// the 'variadic' parameter in: T foo(T a, U b, V variadic...)
    ctorinit            = (1L << 17),   /// can only be set inside constructor
    templateparameter   = (1L << 18),   /// template parameter
    scope_              = (1L << 19),
    immutable_          = (1L << 20),
    ref_                = (1L << 21),
    init                = (1L << 22),   /// has explicit initializer
    manifest            = (1L << 23),   /// manifest constant
    nodtor              = (1L << 24),   /// don't run destructor
    nothrow_            = (1L << 25),   /// never throws exceptions
    pure_               = (1L << 26),   /// pure function
    tls                 = (1L << 27),   /// thread local
    alias_              = (1L << 28),   /// alias parameter
    shared_             = (1L << 29),   /// accessible from multiple threads
    gshared             = (1L << 30),   /// accessible from multiple threads, but not typed as "shared"
    wild                = (1L << 31),   /// for "wild" type constructor
    property            = (1L << 32),
    safe                = (1L << 33),
    trusted             = (1L << 34),
    system              = (1L << 35),
    ctfe                = (1L << 36),   /// can be used in CTFE, even if it is static
    disable             = (1L << 37),   /// for functions that are not callable
    result              = (1L << 38),   /// for result variables passed to out contracts
    nodefaultctor       = (1L << 39),   /// must be set inside constructor
    temp                = (1L << 40),   /// temporary variable
    rvalue              = (1L << 41),   /// force rvalue for variables
    nogc                = (1L << 42),   /// @nogc
    volatile_           = (1L << 43),   /// destined for volatile in the back end
    return_             = (1L << 44),   /// 'return ref' or 'return scope' for function parameters
    autoref             = (1L << 45),   /// Mark for the already deduced 'auto ref' parameter
    inference           = (1L << 46),   /// do attribute inference
    exptemp             = (1L << 47),   /// temporary variable that has lifetime restricted to an expression
    maybescope          = (1L << 48),   /// parameter might be 'scope'
    scopeinferred       = (1L << 49),   /// 'scope' has been inferred and should not be part of mangling
    future              = (1L << 50),   /// introducing new base class function
    local               = (1L << 51),   /// do not forward (see dmd.dsymbol.ForwardingScopeDsymbol).
    returninferred      = (1L << 52),   /// 'return' has been inferred and should not be part of mangling

    TYPECTOR = (const_ | immutable_ | shared_ | wild),
    FUNCATTR = (ref_ | nothrow_ | nogc | pure_ | property | safe | trusted | system),
}

/** Short name for StorageClass, used only in expressions.
 * For clarity keep the long name in the public API. */
alias STC = StorageClass;

extern (C++) __gshared const(StorageClass) STCStorageClass =
    (STC.auto_ | STC.scope_ | STC.static_ | STC.extern_ | STC.const_ | STC.final_ | STC.abstract_ | STC.synchronized_ | STC.deprecated_ | STC.override_ | STC.lazy_ | STC.alias_ | STC.out_ | STC.in_ | STC.manifest | STC.immutable_ | STC.shared_ | STC.wild | STC.nothrow_ | STC.nogc | STC.pure_ | STC.ref_ | STC.return_ | STC.tls | STC.gshared | STC.property | STC.safe | STC.trusted | STC.system | STC.disable);
