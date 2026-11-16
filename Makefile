# perl16: Perl 3.044 for 16-bit MS-DOS, built with Open Watcom
# (docs/DESIGN.md).
#
#   make             build/dev/PERL.EXE, the development build (below)
#   make test        smoke tests of build/dev/PERL.EXE under DOSBox-X,
#                    on an emulated 8086 (tests/run-dos)
#   make test-t      Perl 3.044's own t/ suite under DOSBox-X, checked
#                    against tests/t-baseline.txt (tests/run-t)
#   make variants    the M1 experimental builds in build/var (below),
#                    and FREEMEM.EXE and TICKS.EXE for the probes
#                    (scripts/build-variant, tests/tools)
#   make measure     the M1 stack and memory measurements of the variants
#                    (scripts/stack-probe, scripts/mem-probe;
#                    docs/M1-REPORT.md)
#   make audit       runtime inventory of the interpreter's objects:
#                    build/audit/report.txt (scripts/audit-externals)
#   make reference   fetch the historical MS-DOS port material into
#                    build/reference (not needed to build)
#   make clean       remove build products; keep downloads and tools
#
# build/dev/PERL.EXE and the build/var variants are linked with Open
# Watcom's C runtime. They are development and test binaries only and
# must never be published (docs/DESIGN.md, section 8).
#
# The source is tag perl-3.044 (scripts/fetch-upstream) with patches/*
# applied in order, msdos/ flattened into the top directory as the
# historical port's README says, and perl.c/perly.h generated from perl.y
# (scripts/yacc-perl); it is assembled in build/src. perl16's own C files
# are in msdos/ in this repository.
#
# The Open Watcom toolchain is the snapshot pinned by libc16, fetched by
# the libc16 tree's tools/fetch-watcom into build/tools, as in the other
# gr-dos *16 projects.

UPSTREAM    := build/upstream/perl-3.044
SRC         := build/src
DEV         := build/dev

LIBC16_ROOT ?= build/libc16
LIBC16_DIR  := $(if $(wildcard $(LIBC16_ROOT)/build/stage/VERSION),$(LIBC16_ROOT)/build/stage,$(LIBC16_ROOT))
LIBC16L     := $(LIBC16_DIR)/lib/LIBC16L.LIB
TOOLS_ENV   := build/tools.env
WATCOM_ENV   = . ./$(TOOLS_ENV) && PATH=$$WATCOM/binl64:$$PATH

# Perl 3.044's modules, as in msdos/Makefile, and the historical port's.
PERL_NAMES  = array cmd cons consarg doarg doio dolist dump eval form hash \
              perl perly regcomp regexec stab str toke util
PORT_NAMES  = msdos popen directory
# perl16's own, in msdos/.
P16_NAMES   = mktemp

# Development build: large model, 8086 instructions, Open Watcom's headers
# and runtime. -zc puts string literals in the code segment; without it
# DGROUP overflows (docs/M0-AUDIT.md, section 6). The 32 KB stack is the
# historical port's (/stack:32767).
CC          = wcc
DEV_CFLAGS  = -q -zq -ml -0 -zc -bt=dos -DMSDOS -I$(SRC) -I$$WATCOM/h
DEV_LDOPTS  = option quiet, stack=32k

DEV_OBJS    = $(PERL_NAMES:%=$(DEV)/%.obj) $(PORT_NAMES:%=$(DEV)/%.obj) \
              $(P16_NAMES:%=$(DEV)/%.obj)
PATCHES     = $(sort $(wildcard patches/*.patch))

all: $(DEV)/PERL.EXE

$(DEV)/PERL.EXE: $(DEV_OBJS) $(TOOLS_ENV)
	$(WATCOM_ENV) && wlink $(DEV_LDOPTS), map=$(DEV)/perl.map \
	  system dos name $@ $(DEV_OBJS:%=file %)

$(DEV)/%.obj: $(SRC)/%.c $(SRC)/.stamp $(TOOLS_ENV)
	mkdir -p $(DEV)
	$(WATCOM_ENV) && $(CC) $(DEV_CFLAGS) -fo=$@ $<

$(DEV)/%.obj: msdos/%.c $(TOOLS_ENV)
	mkdir -p $(DEV)
	$(WATCOM_ENV) && $(CC) $(DEV_CFLAGS) -fo=$@ $<

$(SRC)/%.c: $(SRC)/.stamp ;

# The assembled source tree.
$(SRC)/.stamp: $(UPSTREAM)/.git-tree $(PATCHES) scripts/yacc-perl
	rm -rf $(SRC) $(SRC).tmp
	cp -R $(UPSTREAM) $(SRC).tmp
	rm -f $(SRC).tmp/.git-tree
	for p in $(PATCHES); do patch -s -p1 -d $(SRC).tmp < $$p || exit 1; done
	cd $(SRC).tmp && cp msdos/config.h msdos/msdos.c msdos/popen.c \
	  msdos/directory.c . && mkdir sys && cp msdos/dir.h sys/dir.h
	sh scripts/yacc-perl $(SRC).tmp
	mv $(SRC).tmp $(SRC)
	touch $@

$(UPSTREAM)/.git-tree: scripts/fetch-upstream upstream/MANIFEST.sha256
	sh scripts/fetch-upstream $(UPSTREAM)

# The pinned libc16 release (scripts/fetch-libc16), for the toolchain pin
# and the audit. A LIBC16_ROOT given on the command line must be built.
ifeq ($(LIBC16_ROOT),build/libc16)
$(LIBC16L): scripts/fetch-libc16
	sh scripts/fetch-libc16 $(LIBC16_ROOT)
endif

# The Open Watcom snapshot libc16 names, as shell assignments.
$(TOOLS_ENV): $(LIBC16L)
	mkdir -p build
	watcom=$$(sh $(LIBC16_DIR)/tools/fetch-watcom $(CURDIR)/build/tools) \
	  && printf 'WATCOM=%s\nexport WATCOM\n' "$$watcom" > $@

# M1 measurement variants (docs/M1-REPORT.md); dev is build/dev/PERL.EXE
# built again.
VARIANTS    = dev nochk os ox crip stk46 margin rec ss64

variants: $(SRC)/.stamp $(TOOLS_ENV)
	$(WATCOM_ENV) && for v in $(VARIANTS); do \
	  sh scripts/build-variant $$v || exit 1; done
	$(WATCOM_ENV) && for t in freemem ticks; do \
	  wcc -q -zq -ms -0 -bt=dos -I$$WATCOM/h -fo=build/var/$$t.obj \
	    tests/tools/$$t.c && \
	  wlink option quiet system dos name build/var/$$t.exe \
	    file build/var/$$t.obj || exit 1; done
	mv build/var/freemem.exe build/var/FREEMEM.EXE
	mv build/var/ticks.exe build/var/TICKS.EXE

measure: variants $(UPSTREAM)/.git-tree
	perl scripts/stack-probe $(VARIANTS:%=build/var/%/PERL.EXE)
	perl scripts/mem-probe build/var/FREEMEM.EXE $(UPSTREAM) \
	  build/var/dev/PERL.EXE build/var/ss64/PERL.EXE

test: $(DEV)/PERL.EXE
	perl tests/run-dos $(DEV)/PERL.EXE tests/smoke

test-t: $(DEV)/PERL.EXE $(UPSTREAM)/.git-tree
	perl tests/run-t $(DEV)/PERL.EXE $(UPSTREAM) tests/t-baseline.txt

audit: $(DEV_OBJS) $(LIBC16L) $(TOOLS_ENV)
	mkdir -p build/audit
	$(WATCOM_ENV) && perl scripts/audit-externals build/audit $(LIBC16L) \
	  $(DEV_OBJS)

reference:
	sh scripts/fetch-reference build/reference

clean:
	rm -rf $(SRC) $(SRC).tmp $(DEV) build/var build/audit build/run-dos \
	  build/run-t build/stack-probe build/mem-probe

# The assembled sources are made by one rule; make must not delete them.
.SECONDARY:

.PHONY: all test test-t variants measure audit reference clean
