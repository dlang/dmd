/**
 * D header file for Hurd extensions to POSIX's time.h.
 *
 * Copyright: Copyright (c) 2026 D Language Foundation
 * License:   $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 */
module core.sys.hurd.time;

public import core.sys.posix.time;

version (Hurd):

enum CLOCK_MONOTONIC_RAW      = 4;
enum CLOCK_REALTIME_COARSE    = 5;
enum CLOCK_MONOTONIC_COARSE   = 6;
