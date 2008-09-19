/**
 * D header file for C99.
 *
 * Copyright: Public Domain
 * License:   Public Domain
 * Authors:   Sean Kelly, Walter Bright
 * Standards: ISO/IEC 9899:1999 (E)
 */
module stdc.tgmath;

private import stdc.config;
private static import stdc.math;
private static import stdc.complex;

extern (C):

alias stdc.math.acos          acos;
alias stdc.math.acosf         acos;
alias stdc.math.acosl         acos;

alias stdc.complex.cacos      acos;
alias stdc.complex.cacosf     acos;
alias stdc.complex.cacosl     acos;

alias stdc.math.asin          asin;
alias stdc.math.asinf         asin;
alias stdc.math.asinl         asin;

alias stdc.complex.casin      asin;
alias stdc.complex.casinf     asin;
alias stdc.complex.casinl     asin;

alias stdc.math.atan          atan;
alias stdc.math.atanf         atan;
alias stdc.math.atanl         atan;

alias stdc.complex.catan      atan;
alias stdc.complex.catanf     atan;
alias stdc.complex.catanl     atan;

alias stdc.math.atan2         atan2;
alias stdc.math.atan2f        atan2;
alias stdc.math.atan2l        atan2;

alias stdc.math.cos           cos;
alias stdc.math.cosf          cos;
alias stdc.math.cosl          cos;

alias stdc.complex.ccos       cos;
alias stdc.complex.ccosf      cos;
alias stdc.complex.ccosl      cos;

alias stdc.math.sin           sin;
alias stdc.math.sinf          sin;
alias stdc.math.sinl          sin;

alias stdc.complex.csin       csin;
alias stdc.complex.csinf      csin;
alias stdc.complex.csinl      csin;

alias stdc.math.tan           tan;
alias stdc.math.tanf          tan;
alias stdc.math.tanl          tan;

alias stdc.complex.ctan       tan;
alias stdc.complex.ctanf      tan;
alias stdc.complex.ctanl      tan;

alias stdc.math.acosh         acosh;
alias stdc.math.acoshf        acosh;
alias stdc.math.acoshl        acosh;

alias stdc.complex.cacosh     acosh;
alias stdc.complex.cacoshf    acosh;
alias stdc.complex.cacoshl    acosh;

alias stdc.math.asinh         asinh;
alias stdc.math.asinhf        asinh;
alias stdc.math.asinhl        asinh;

alias stdc.complex.casinh     asinh;
alias stdc.complex.casinhf    asinh;
alias stdc.complex.casinhl    asinh;

alias stdc.math.atanh         atanh;
alias stdc.math.atanhf        atanh;
alias stdc.math.atanhl        atanh;

alias stdc.complex.catanh     atanh;
alias stdc.complex.catanhf    atanh;
alias stdc.complex.catanhl    atanh;

alias stdc.math.cosh          cosh;
alias stdc.math.coshf         cosh;
alias stdc.math.coshl         cosh;

alias stdc.complex.ccosh      cosh;
alias stdc.complex.ccoshf     cosh;
alias stdc.complex.ccoshl     cosh;

alias stdc.math.sinh          sinh;
alias stdc.math.sinhf         sinh;
alias stdc.math.sinhl         sinh;

alias stdc.complex.csinh      sinh;
alias stdc.complex.csinhf     sinh;
alias stdc.complex.csinhl     sinh;

alias stdc.math.tanh          tanh;
alias stdc.math.tanhf         tanh;
alias stdc.math.tanhl         tanh;

alias stdc.complex.ctanh      tanh;
alias stdc.complex.ctanhf     tanh;
alias stdc.complex.ctanhl     tanh;

alias stdc.math.exp           exp;
alias stdc.math.expf          exp;
alias stdc.math.expl          exp;

alias stdc.complex.cexp       exp;
alias stdc.complex.cexpf      exp;
alias stdc.complex.cexpl      exp;

alias stdc.math.exp2          exp2;
alias stdc.math.exp2f         exp2;
alias stdc.math.exp2l         exp2;

alias stdc.math.expm1         expm1;
alias stdc.math.expm1f        expm1;
alias stdc.math.expm1l        expm1;

alias stdc.math.frexp         frexp;
alias stdc.math.frexpf        frexp;
alias stdc.math.frexpl        frexp;

alias stdc.math.ilogb         ilogb;
alias stdc.math.ilogbf        ilogb;
alias stdc.math.ilogbl        ilogb;

alias stdc.math.ldexp         ldexp;
alias stdc.math.ldexpf        ldexp;
alias stdc.math.ldexpl        ldexp;

alias stdc.math.log           log;
alias stdc.math.logf          log;
alias stdc.math.logl          log;

alias stdc.complex.clog       log;
alias stdc.complex.clogf      log;
alias stdc.complex.clogl      log;

alias stdc.math.log10         log10;
alias stdc.math.log10f        log10;
alias stdc.math.log10l        log10;

alias stdc.math.log1p         log1p;
alias stdc.math.log1pf        log1p;
alias stdc.math.log1pl        log1p;

alias stdc.math.log2          log1p;
alias stdc.math.log2f         log1p;
alias stdc.math.log2l         log1p;

alias stdc.math.logb          log1p;
alias stdc.math.logbf         log1p;
alias stdc.math.logbl         log1p;

alias stdc.math.modf          modf;
alias stdc.math.modff         modf;
alias stdc.math.modfl         modf;

alias stdc.math.scalbn        scalbn;
alias stdc.math.scalbnf       scalbn;
alias stdc.math.scalbnl       scalbn;

alias stdc.math.scalbln       scalbln;
alias stdc.math.scalblnf      scalbln;
alias stdc.math.scalblnl      scalbln;

alias stdc.math.cbrt          cbrt;
alias stdc.math.cbrtf         cbrt;
alias stdc.math.cbrtl         cbrt;

alias stdc.math.fabs          fabs;
alias stdc.math.fabsf         fabs;
alias stdc.math.fabsl         fabs;

alias stdc.complex.cabs       fabs;
alias stdc.complex.cabsf      fabs;
alias stdc.complex.cabsl      fabs;

alias stdc.math.hypot         hypot;
alias stdc.math.hypotf        hypot;
alias stdc.math.hypotl        hypot;

alias stdc.math.pow           pow;
alias stdc.math.powf          pow;
alias stdc.math.powl          pow;

alias stdc.complex.cpow       pow;
alias stdc.complex.cpowf      pow;
alias stdc.complex.cpowl      pow;

alias stdc.math.sqrt          sqrt;
alias stdc.math.sqrtf         sqrt;
alias stdc.math.sqrtl         sqrt;

alias stdc.complex.csqrt      sqrt;
alias stdc.complex.csqrtf     sqrt;
alias stdc.complex.csqrtl     sqrt;

alias stdc.math.erf           erf;
alias stdc.math.erff          erf;
alias stdc.math.erfl          erf;

alias stdc.math.erfc          erfc;
alias stdc.math.erfcf         erfc;
alias stdc.math.erfcl         erfc;

alias stdc.math.lgamma        lgamma;
alias stdc.math.lgammaf       lgamma;
alias stdc.math.lgammal       lgamma;

alias stdc.math.tgamma        tgamma;
alias stdc.math.tgammaf       tgamma;
alias stdc.math.tgammal       tgamma;

alias stdc.math.ceil          ceil;
alias stdc.math.ceilf         ceil;
alias stdc.math.ceill         ceil;

alias stdc.math.floor         floor;
alias stdc.math.floorf        floor;
alias stdc.math.floorl        floor;

alias stdc.math.nearbyint     nearbyint;
alias stdc.math.nearbyintf    nearbyint;
alias stdc.math.nearbyintl    nearbyint;

alias stdc.math.rint          rint;
alias stdc.math.rintf         rint;
alias stdc.math.rintl         rint;

alias stdc.math.lrint         lrint;
alias stdc.math.lrintf        lrint;
alias stdc.math.lrintl        lrint;

alias stdc.math.llrint        llrint;
alias stdc.math.llrintf       llrint;
alias stdc.math.llrintl       llrint;

alias stdc.math.round         round;
alias stdc.math.roundf        round;
alias stdc.math.roundl        round;

alias stdc.math.lround        lround;
alias stdc.math.lroundf       lround;
alias stdc.math.lroundl       lround;

alias stdc.math.llround       llround;
alias stdc.math.llroundf      llround;
alias stdc.math.llroundl      llround;

alias stdc.math.trunc         trunc;
alias stdc.math.truncf        trunc;
alias stdc.math.truncl        trunc;

alias stdc.math.fmod          fmod;
alias stdc.math.fmodf         fmod;
alias stdc.math.fmodl         fmod;

alias stdc.math.remainder     remainder;
alias stdc.math.remainderf    remainder;
alias stdc.math.remainderl    remainder;

alias stdc.math.remquo        remquo;
alias stdc.math.remquof       remquo;
alias stdc.math.remquol       remquo;

alias stdc.math.copysign      copysign;
alias stdc.math.copysignf     copysign;
alias stdc.math.copysignl     copysign;

alias stdc.math.nan           nan;
alias stdc.math.nanf          nan;
alias stdc.math.nanl          nan;

alias stdc.math.nextafter     nextafter;
alias stdc.math.nextafterf    nextafter;
alias stdc.math.nextafterl    nextafter;

alias stdc.math.nexttoward    nexttoward;
alias stdc.math.nexttowardf   nexttoward;
alias stdc.math.nexttowardl   nexttoward;

alias stdc.math.fdim          fdim;
alias stdc.math.fdimf         fdim;
alias stdc.math.fdiml         fdim;

alias stdc.math.fmax          fmax;
alias stdc.math.fmaxf         fmax;
alias stdc.math.fmaxl         fmax;

alias stdc.math.fmin          fmin;
alias stdc.math.fmin          fmin;
alias stdc.math.fminl         fmin;

alias stdc.math.fma           fma;
alias stdc.math.fmaf          fma;
alias stdc.math.fmal          fma;

alias stdc.complex.carg       carg;
alias stdc.complex.cargf      carg;
alias stdc.complex.cargl      carg;

alias stdc.complex.cimag      cimag;
alias stdc.complex.cimagf     cimag;
alias stdc.complex.cimagl     cimag;

alias stdc.complex.conj       conj;
alias stdc.complex.conjf      conj;
alias stdc.complex.conjl      conj;

alias stdc.complex.cproj      cproj;
alias stdc.complex.cprojf     cproj;
alias stdc.complex.cprojl     cproj;

//alias stdc.complex.creal      creal;
//alias stdc.complex.crealf     creal;
//alias stdc.complex.creall     creal;
