// PERMUTE_ARGS:
// POST_SCRIPT: compilable/extra-files/macho_archive_alignment.sh

// ld rejects Mach-O archives whose members are not 8-byte aligned, so
// `dmd -lib` must align every member. The post script builds the archives
// itself.
extern (C) int foo() { return 42; }
