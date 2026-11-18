# perl16: Perl 3.044 for 16-bit MS-DOS, built with Open Watcom
# (docs/DESIGN.md).
#
#   make             build/dev/PERL.EXE, the development build (below)
#   make test        smoke tests of build/dev/PERL.EXE under DOSBox-X,
#                    on an emulated 8086 (tests/run-dos), and tests of
#                    it installed on other drives and directories
#                    (tests/run-install)
#   make test-t      Perl 3.044's own t/ suite under DOSBox-X, checked
#                    against tests/t-baseline.txt (tests/run-t)
#   make variants    the M1 experimental builds in build/var (below),
#                    and FREEMEM.EXE and TICKS.EXE for the probes
#                    (scripts/build-variant, tests/tools)
#   make measure     the M1 stack and memory measurements of the variants
#                    (scripts/stack-probe, scripts/mem-probe;
#                    docs/M1-REPORT.md)
#   make audit       runtime inventory of the interpreter's objects:
#                    build/audit/report.txt (scripts/audit-externals),
#                    and of its sources recompiled against libc16's and
#                    libkitchen16's headers and linked with both
#                    libraries: build/audit/libc16/report.txt
#                    (scripts/audit-libc16; docs/M3-RUNTIME-AUDIT.md)
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
LIBKITCHEN16_ROOT ?= build/libkitchen16
LIBKITCHEN16_DIR  := $(if $(wildcard $(LIBKITCHEN16_ROOT)/build/stage/VERSION),$(LIBKITCHEN16_ROOT)/build/stage,$(LIBKITCHEN16_ROOT))
LIBK16L     := $(LIBKITCHEN16_DIR)/lib/LIBK16L.LIB
TOOLS_ENV   := build/tools.env
WATCOM_ENV   = . ./$(TOOLS_ENV) && PATH=$$WATCOM/binl64:$$PATH

# Perl 3.044's modules, as in msdos/Makefile, and the historical port's.
PERL_NAMES  = array cmd cons consarg doarg doio dolist dump eval form hash \
              perl perly regcomp regexec stab str toke util
PORT_NAMES  = msdos popen directory
# perl16's own, in msdos/: the executable's directory for @INC, the -e
# temporary file, and globbing (docs/M2-REPORT.md).
P16_NAMES   = exepath etemp dosglob
P16_HEADERS = $(wildcard msdos/*.h)

# Development build: large model, 8086 instructions, Open Watcom's headers
# and runtime. -zc puts string literals in the code segment; without it
# DGROUP overflows (docs/M0-AUDIT.md, section 6).
#
# The stack (docs/M2-REPORT.md, section 4): -DCRIPPLED_CC, as the
# historical port was built, makes str_get, str_gnum and str_true
# functions, which shrinks eval()'s frame from 780 to 186 bytes;
# msdos/stk16.asm replaces Open Watcom's __STK with a check that keeps
# STK16_MARGIN bytes in reserve and reports overflow on standard error
# with exit status 255; and the stack is as large as DGROUP allows while
# leaving DGROUP_MIN_FREE bytes free for the near heap, which child
# processes need (scripts/check-dgroup checks the map).
CC          = wcc
AS          = wasm
STACK       ?= 51k
STK16_MARGIN ?= 2048
DGROUP_MIN_FREE ?= 2048
DEV_CFLAGS  = -q -zq -ml -0 -zc -bt=dos -DMSDOS -DCRIPPLED_CC -I$(SRC) \
              -Imsdos -I$$WATCOM/h
DEV_AFLAGS  = -q -ml -0 -dSTK16_MARGIN=$(STK16_MARGIN)
DEV_LDOPTS  = disable 1027 option quiet, stack=$(STACK)

DEV_OBJS    = $(DEV)/stk16.obj $(PERL_NAMES:%=$(DEV)/%.obj) \
              $(PORT_NAMES:%=$(DEV)/%.obj) $(P16_NAMES:%=$(DEV)/%.obj)
PATCHES     = $(sort $(wildcard patches/*.patch))

all: $(DEV)/PERL.EXE

$(DEV)/PERL.EXE: $(DEV_OBJS) $(TOOLS_ENV) scripts/check-dgroup Makefile
	$(WATCOM_ENV) && wlink $(DEV_LDOPTS), map=$(DEV)/perl.map \
	  system dos name $@.tmp $(DEV_OBJS:%=file %)
	perl scripts/check-dgroup $(DEV)/perl.map $(DGROUP_MIN_FREE)
	mv $@.tmp $@

$(DEV)/%.obj: msdos/%.asm $(TOOLS_ENV) Makefile
	mkdir -p $(DEV)
	$(WATCOM_ENV) && $(AS) $(DEV_AFLAGS) -fo=$@ $<

$(DEV)/%.obj: $(SRC)/%.c $(SRC)/.stamp $(P16_HEADERS) $(TOOLS_ENV) Makefile
	mkdir -p $(DEV)
	$(WATCOM_ENV) && $(CC) $(DEV_CFLAGS) -fo=$@ $<

$(DEV)/%.obj: msdos/%.c $(P16_HEADERS) $(TOOLS_ENV) Makefile
	mkdir -p $(DEV)
	$(WATCOM_ENV) && $(CC) $(DEV_CFLAGS) -fo=$@ $<

$(SRC)/%.c: $(SRC)/.stamp ;

# The assembled source tree.
$(SRC)/.stamp: $(UPSTREAM)/.git-tree $(PATCHES) scripts/yacc-perl \
  upstream/parser.sha256
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

# The pinned libkitchen16 release (scripts/fetch-libkitchen16): floating
# point, formatting and <math.h> (docs/M3-RUNTIME-AUDIT.md, section 11),
# for the audit until M3.4 links it. It must name the same Open Watcom
# snapshot as libc16.
ifeq ($(LIBKITCHEN16_ROOT),build/libkitchen16)
$(LIBK16L): scripts/fetch-libkitchen16
	sh scripts/fetch-libkitchen16 $(LIBKITCHEN16_ROOT)
endif

# The Open Watcom snapshot libc16 names, as shell assignments; the
# libkitchen16 release must name the same one.
$(TOOLS_ENV): $(LIBC16L) $(LIBK16L)
	test "$$(sed -n 's/^sha256=//p' $(LIBC16_DIR)/tools/fetch-watcom)" \
	  = "$$(sed -n 's/^sha256=//p' $(LIBKITCHEN16_DIR)/tools/fetch-watcom)"
	mkdir -p build
	watcom=$$(sh $(LIBC16_DIR)/tools/fetch-watcom $(CURDIR)/build/tools) \
	  && printf 'WATCOM=%s\nexport WATCOM\n' "$$watcom" > $@

# M1 measurement variants (docs/M1-REPORT.md); dev is the M1 development
# build (32 KB stack, no CRIPPLED_CC, Open Watcom's __STK), not build/dev.
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

# DOS tools for tests/run-install: unit tests of perl16's own code, built
# like PERL.EXE, and ERR2OUT.EXE, which lets a test see standard error.
# Like PERL.EXE, never to be published.
TEST_TOOLS  = $(DEV)/EXETEST.EXE $(DEV)/ETEMPTST.EXE $(DEV)/ERR2OUT.EXE

$(DEV)/EXETEST.EXE: tests/tools/exetest.c $(DEV)/exepath.obj $(P16_HEADERS) \
  $(TOOLS_ENV)
	$(WATCOM_ENV) && $(CC) $(DEV_CFLAGS) -fo=$(DEV)/exetest.obj $< && \
	  wlink option quiet system dos name $@ file $(DEV)/exetest.obj \
	  file $(DEV)/exepath.obj

$(DEV)/ETEMPTST.EXE: tests/tools/etemptst.c msdos/etemp.c $(P16_HEADERS) \
  $(TOOLS_ENV)
	$(WATCOM_ENV) && $(CC) $(DEV_CFLAGS) -fo=$(DEV)/etemptst.obj $< && \
	  wlink option quiet system dos name $@ file $(DEV)/etemptst.obj

$(DEV)/ERR2OUT.EXE: tests/tools/err2out.c $(TOOLS_ENV)
	$(WATCOM_ENV) && $(CC) -q -zq -ms -0 -bt=dos -I$$WATCOM/h \
	  -fo=$(DEV)/err2out.obj $< && \
	  wlink option quiet system dos name $@ file $(DEV)/err2out.obj

test: $(DEV)/PERL.EXE $(TEST_TOOLS)
	perl tests/run-dos $(DEV)/PERL.EXE tests/smoke
	perl tests/run-install $(DEV)/PERL.EXE $(TEST_TOOLS)

test-t: $(DEV)/PERL.EXE $(UPSTREAM)/.git-tree
	perl tests/run-t $(DEV)/PERL.EXE $(UPSTREAM) tests/t-baseline.txt

audit: $(DEV_OBJS) $(LIBC16L) $(LIBK16L) $(TOOLS_ENV) scripts/audit-libc16
	mkdir -p build/audit build/audit/libc16
	$(WATCOM_ENV) && perl scripts/audit-externals build/audit $(LIBC16L) \
	  $(DEV_OBJS)
	$(WATCOM_ENV) && perl scripts/audit-libc16 \
	  --libkitchen16 $(LIBKITCHEN16_DIR) build/audit/libc16 \
	  $(LIBC16_DIR) build/audit/externals.txt \
	  $(PERL_NAMES:%=$(SRC)/%.c) $(PORT_NAMES:%=$(SRC)/%.c) \
	  $(P16_NAMES:%=msdos/%.c)

reference:
	sh scripts/fetch-reference build/reference

clean:
	rm -rf $(SRC) $(SRC).tmp $(DEV) build/var build/audit build/run-dos \
	  build/run-t build/stack-probe build/mem-probe

# The assembled sources are made by one rule; make must not delete them.
.SECONDARY:

.PHONY: all test test-t variants measure audit reference clean
