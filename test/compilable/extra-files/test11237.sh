#!/usr/bin/env bash

if [[ $OS == linux || $OS == freebsd ]]; then
    nm -S ${OUTPUT_BASE}_0.o | grep "00010000 B _D9test112376Buffer6__initZ"
fi
