$(warning ===== DEPRECATION NOTICE ===== )
$(warning ===== DEPRECATION: posix.mak is deprecated. Please use generic Makefile instead.)
$(warning ============================== )

# forward everything to Makefile

target:
	$(MAKE) -f Makefile $@

%:
	$(MAKE) -f Makefile $@
