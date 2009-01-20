# Makefile to build the composite D runtime library for Linux
# Designed to work with GNU make
# Targets:
#	make
#		Same as make all
#	make debug
#		Build the debug version of the library
#   make release
#       Build the release version of the library
#   make doc
#       Generate documentation
#	make clean
#		Delete all files created by build process

# Essentials

LIBDIR:=../lib
DOCDIR:=../doc
LIBBASENAME=libdruntime.a

DIR_CC=common
DIR_RT=compiler/dmd
DIR_GC=gc/basic

# Symbols

DMD=dmd

# Targets

all     : debug release doc unittest $(LIBDIR)/$(LIBBASENAME)

# unittest :
# 	$(MAKE) -fdmd-posix.mak lib MAKE_LIB="unittest"
# 	dmd -unittest unittest ../import/core/stdc/stdarg \
# 		-defaultlib="$(DUP_TARGET)" -debuglib="$(DUP_TARGET)"
# 	$(RM) stdarg.o
# 	./unittest

debug release unittest :
	@$(MAKE) -C $(DIR_CC) --no-print-directory -fposix.mak $@
	@$(MAKE) -C $(DIR_RT) --no-print-directory -fposix.mak $@
	@$(MAKE) -C $(DIR_GC) --no-print-directory -fposix.mak $@
	@$(DMD) -lib -of$(LIBDIR)/$@/$(LIBBASENAME) \
		$(LIBDIR)/$@/libdruntime-core.a \
		$(LIBDIR)/$@/libdruntime-rt-dmd.a \
		$(LIBDIR)/$@/libdruntime-gc-basic.a

$(LIBDIR)/$(LIBBASENAME) : $(LIBDIR)/release/$(LIBBASENAME)
	ln -sf $(realpath $<) $@

doc : $(ALL_DOCS)
	$(MAKE) -C $(DIR_CC) --no-print-directory -fposix.mak doc
	$(MAKE) -C $(DIR_RT) --no-print-directory -fposix.mak doc
	$(MAKE) -C $(DIR_GC) --no-print-directory -fposix.mak doc

######################################################

clean :
	$(MAKE) -C $(DIR_CC) --no-print-directory -fposix.mak clean
	$(MAKE) -C $(DIR_RT) --no-print-directory -fposix.mak clean
	$(MAKE) -C $(DIR_GC) --no-print-directory -fposix.mak clean
#find . -name "*.di" | xargs $(RM)
	rm -rf $(LIBDIR) $(DOCDIR)

# install :
# 	make -C $(DIR_CC) --no-print-directory -fposix.mak install
# 	make -C $(DIR_RT) --no-print-directory -fposix.mak install
# 	make -C $(DIR_GC) --no-print-directory -fposix.mak install
# 	$(CP) $(LIB_MASK) $(LIB_DEST)/.
# 	$(CP) $(DUP_MASK) $(LIB_DEST)/.

