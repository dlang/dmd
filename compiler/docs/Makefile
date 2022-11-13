DMD=dmd
GENERATED=../generated
DMD_MAN_PAGE=man/man1/dmd.1
DIFFABLE=0

build: $(GENERATED)/build
	./$(GENERATED)/build HOST_DMD="$(DMD)" DIFFABLE="$(DIFFABLE)" man

preview: $(GENERATED)/docs/$(DMD_MAN_PAGE)
	man -l $(GENERATED)/docs/$(DMD_MAN_PAGE)

$(GENERATED)/docs/%: $(GENERATED)/build
	$(GENERATED)/build $@

$(GENERATED)/build: ../src/build.d
	$(DMD) -of$@ ../src/build.d
