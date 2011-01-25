/**
 * D header file for C99.
 *
 * Copyright: Copyright Sean Kelly 2005 - 2009.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Sean Kelly
 * Standards: ISO/IEC 9899:1999 (E)
 */

/*          Copyright Sean Kelly 2005 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module core.stdc.float_;

extern (C):

enum FLT_ROUNDS                 = 1;
enum FLT_EVAL_METHOD    = 2;
enum FLT_RADIX                  = 2;

enum DECIMAL_DIG                = real.dig;
enum FLT_DIG                    = float.dig;
enum DBL_DIG                    = double.dig;
enum LDBL_DIG                   = real.dig;

enum FLT_MANT_DIG               = float.mant_dig;
enum DBL_MANT_DIG               = double.mant_dig;
enum LDBL_MANT_DIG              = real.mant_dig;

enum FLT_MIN                    = float.min;
enum DBL_MIN                    = double.min;
enum LDBL_MIN                   = real.min;

enum FLT_MAX                    = float.max;
enum DBL_MAX                    = double.max;
enum LDBL_MAX                   = real.max;

enum FLT_EPSILON                = float.epsilon;
enum DBL_EPSILON                = double.epsilon;
enum LDBL_EPSILON               = real.epsilon;

enum FLT_MIN_EXP                = float.min_exp;
enum DBL_MIN_EXP                = double.min_exp;
enum LDBL_MIN_EXP               = real.min_exp;

enum FLT_MAX_EXP                = float.max_exp;
enum DBL_MAX_EXP                = double.max_exp;
enum LDBL_MAX_EXP               = real.max_exp;

enum FLT_MIN_10_EXP             = float.min_10_exp;
enum DBL_MIN_10_EXP             = double.min_10_exp;
enum LDBL_MIN_10_EXP    = real.min_10_exp;

enum FLT_MAX_10_EXP             = float.max_10_exp;
enum DBL_MAX_10_EXP             = double.max_10_exp;
enum LDBL_MAX_10_EXP    = real.max_10_exp;
