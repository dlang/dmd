$(warning ===== DEPRECATION NOTICE ===== )
$(warning ===== DEPRECATION: posix.mak is deprecated. Please use generic Makefile instead.)
$(warning ============================== )

# forward everything to Makefile

all:
	$(MAKE) -f Makefile $@

%:
	$(MAKE) -f Makefile $@
