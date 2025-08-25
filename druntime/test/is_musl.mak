ifndef IS_MUSL # LDC defines it externally
    ifeq ($(OS),linux)
        # FIXME: detect musl libc robustly; just checking Alpine Linux' apk tool for now
        ifeq (1,$(shell which apk >/dev/null 2>&1 && echo 1))
            IS_MUSL := 1
        endif
    endif
endif
