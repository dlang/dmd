DMD=dmd
GENERATED=../generated
DMD_MAN_PAGE=man/man1/dmd.1

build: $(GENERATED)/build
	./$(GENERATED)/build man

preview: $(GENERATED)/docs/$(DMD_MAN_PAGE)
	man -l $(GENERATED)/docs/$(DMD_MAN_PAGE)

$(GENERATED)/docs/%: $(GENERATED)/build
	$(GENERATED)/build $@

$(GENERATED)/build: ../src/build.d
	$(DMD) -of$@ ../src/build.d

