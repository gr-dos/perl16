# perl16: Perl 3.044 for 16-bit MS-DOS, built with Open Watcom
# (docs/DESIGN.md).
#
#   make             build/dev/PERL.EXE, the development build (below)
#   make test        smoke tests of build/dev/PERL.EXE under DOSBox-X,
#                    on an emulated 8086 (tests/run-dos), and tests of
#                    it installed on other drives and directories
#                    (tests/run-install)
#   make rt          build/rt/PERL.EXE, the runtime build: libc16 and
#                    libkitchen16 instead of Open Watcom's runtime (M3.4)
#   make test-rt     the smoke and installation tests of build/rt/PERL.EXE
#   make test-t      Perl 3.044's own t/ suite under DOSBox-X, checked
#                    against tests/t-baseline.txt (tests/run-t)
#   make test-t-rt   the same, under build/rt/PERL.EXE
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
              -Imsdos -I$$WATCOM/h -fi=msdos/p16rt.h
DEV_AFLAGS  = -q -ml -0 -dSTK16_MARGIN=$(STK16_MARGIN)
DEV_LDOPTS  = disable 1027 option quiet, stack=$(STACK)

DEV_OBJS    = $(DEV)/stk16.obj $(PERL_NAMES:%=$(DEV)/%.obj) \
              $(PORT_NAMES:%=$(DEV)/%.obj) $(P16_NAMES:%=$(DEV)/%.obj)

# Runtime build (M3.4, #16 and #17; docs/M3-RUNTIME-AUDIT.md, section
# 11.6): the same sources compiled as a libc16 and libkitchen16 consumer
# is, and linked with their libraries instead of Open Watcom's runtime.
# -zl -zld -x keep Open Watcom's headers and library records out, -fpc
# makes floating point calls to libkitchen16's helpers, and msdos/p16rt.h,
# force-included, puts every library prototype in scope (P16_RT).
# -wx shows every warning; each module's go to its .err file beside the
# object, and scripts/check-w131 fails the build on W131 (no prototype)
# for a function of either library (#16). libkitchen16 comes first, in
# the include path and the link. RT_NAMES are perl16's for libc16 alone:
# environ and the exec family; p16init.asm puts environ's set-up in
# libc16's init table.
RT          := build/rt
RT_NAMES    = environ exec16
RT_CFLAGS   = -q -zq -zl -zld -x -ml -0 -fpc -zc -bt=dos -DMSDOS \
              -DCRIPPLED_CC -DP16_RT -fi=msdos/p16rt.h -wx -I$(SRC) -Imsdos \
              -I$(LIBKITCHEN16_DIR)/include -I$(LIBC16_DIR)/include
RT_AFLAGS   = $(DEV_AFLAGS) -dP16_RT
RT_OBJS     = $(RT)/stk16.obj $(PERL_NAMES:%=$(RT)/%.obj) \
              $(PORT_NAMES:%=$(RT)/%.obj) $(P16_NAMES:%=$(RT)/%.obj) \
              $(RT_NAMES:%=$(RT)/%.obj) $(RT)/p16init.obj
RT_LDOPTS   = option quiet, nodefaultlibs, stack=$(STACK)
RT_SYMS     = $(RT)/libc16.lst $(RT)/libk16.lst
# Compile one module of the runtime build: wcc's output goes to the
# module's .err file, shown only if the compile fails, and that file is
# checked for library functions called without a prototype.
RT_COMPILE  = rm -f $(@:.obj=.err) && $(WATCOM_ENV) && \
              { $(CC) $(RT_CFLAGS) -fr=$(@:.obj=.err) -fo=$@ $< >/dev/null \
                || { cat $(@:.obj=.err); exit 1; }; } && \
              { perl scripts/check-w131 $(RT_SYMS) -- $(@:.obj=.err) \
                || { rm -f $@; exit 1; }; }

# tests/run-install's DOS tools (below)
TEST_TOOLS  = $(DEV)/EXETEST.EXE $(DEV)/ETEMPTST.EXE $(DEV)/ERR2OUT.EXE

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

rt: $(RT)/PERL.EXE

# The runtime build's tests: the same smoke and installation tests, in
# their own work directories, and EXECLTST.EXE; then tests/smoke-rt,
# its own cases (system() with %ENV, #22, with TAILTST.EXE; numeric
# comparisons, #16, with FPCTST.EXE).
test-rt: $(RT)/PERL.EXE $(TEST_TOOLS) $(RT)/EXECLTST.EXE $(DEV)/TAILTST.EXE \
  $(RT)/FPCTST.EXE
	WORK=build/run-dos-rt BUILD=rt perl tests/run-dos $(RT)/PERL.EXE tests/smoke
	WORK=build/run-dos-rt2 BUILD=rt \
	  FILES="$(DEV)/TAILTST.EXE $(RT)/FPCTST.EXE" perl tests/run-dos \
	  $(RT)/PERL.EXE tests/smoke-rt
	WORK=build/run-install-rt perl tests/run-install $(RT)/PERL.EXE \
	  $(TEST_TOOLS) $(RT)/EXECLTST.EXE

# A unit test of exec16.c's execl(), which only the runtime build has,
# linked like it. Never to be published.
EXECLTST_OBJS = $(RT)/execltst.obj $(RT)/stk16.obj $(RT)/exec16.obj \
  $(RT)/environ.obj $(RT)/p16init.obj

$(RT)/EXECLTST.EXE: $(EXECLTST_OBJS) $(LIBC16L) $(LIBK16L) $(TOOLS_ENV)
	$(WATCOM_ENV) && wlink $(RT_LDOPTS) format dos name $@ \
	  $(EXECLTST_OBJS:%=file %) library $(LIBK16L) library $(LIBC16L)

# FPCTST.EXE, the C layer of tests/smoke-rt/fpcmp.pl (#16): the
# compiler's comparisons and p16fp.h's, compiled like the runtime build.
FPCTST_OBJS = $(RT)/fpctst.obj $(RT)/stk16.obj $(RT)/p16fp.obj

$(RT)/FPCTST.EXE: $(FPCTST_OBJS) $(LIBC16L) $(LIBK16L) $(TOOLS_ENV)
	$(WATCOM_ENV) && wlink $(RT_LDOPTS) format dos name $@ \
	  $(FPCTST_OBJS:%=file %) library $(LIBK16L) library $(LIBC16L)

$(RT)/fpctst.obj: tests/tools/fpctst.c $(P16_HEADERS) $(RT_SYMS) \
  $(TOOLS_ENV) scripts/check-w131 Makefile
	$(RT_COMPILE)

$(RT)/execltst.obj: tests/tools/execltst.c $(P16_HEADERS) $(RT_SYMS) \
  $(TOOLS_ENV) scripts/check-w131 Makefile
	$(RT_COMPILE)

# No check-dgroup: libc16's large-model heap grows the program's memory
# block above the stack, outside DGROUP, so DGROUP_MIN_FREE (Open
# Watcom's near heap for children) doesn't apply. #17 sizes the stack.
$(RT)/PERL.EXE: $(RT_OBJS) $(LIBC16L) $(LIBK16L) $(TOOLS_ENV) Makefile
	$(WATCOM_ENV) && wlink $(RT_LDOPTS), map=$(RT)/perl.map \
	  format dos name $@.tmp $(RT_OBJS:%=file %) \
	  library $(LIBK16L) library $(LIBC16L)
	mv $@.tmp $@

# The libraries' symbols, for scripts/check-w131.
$(RT)/libc16.lst: $(LIBC16L) $(TOOLS_ENV)
	mkdir -p $(RT)
	$(WATCOM_ENV) && wlib -q -l=$@ $(LIBC16L)

$(RT)/libk16.lst: $(LIBK16L) $(TOOLS_ENV)
	mkdir -p $(RT)
	$(WATCOM_ENV) && wlib -q -l=$@ $(LIBK16L)

$(RT)/%.obj: msdos/%.asm $(TOOLS_ENV) Makefile
	mkdir -p $(RT)
	$(WATCOM_ENV) && $(AS) $(RT_AFLAGS) -fo=$@ $<

$(RT)/%.obj: $(SRC)/%.c $(SRC)/.stamp $(P16_HEADERS) $(RT_SYMS) \
  $(TOOLS_ENV) scripts/check-w131 Makefile
	mkdir -p $(RT)
	$(RT_COMPILE)

$(RT)/%.obj: msdos/%.c $(P16_HEADERS) $(RT_SYMS) $(TOOLS_ENV) \
  scripts/check-w131 Makefile
	mkdir -p $(RT)
	$(RT_COMPILE)

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
# Like PERL.EXE, never to be published. (TEST_TOOLS is set with the
# other variables, above: test-rt names it as a prerequisite first.)

$(DEV)/EXETEST.EXE: tests/tools/exetest.c $(DEV)/exepath.obj $(P16_HEADERS) \
  $(TOOLS_ENV)
	$(WATCOM_ENV) && $(CC) $(DEV_CFLAGS) -fo=$(DEV)/exetest.obj $< && \
	  wlink option quiet system dos name $@ file $(DEV)/exetest.obj \
	  file $(DEV)/exepath.obj

$(DEV)/ETEMPTST.EXE: tests/tools/etemptst.c msdos/etemp.c $(P16_HEADERS) \
  $(TOOLS_ENV)
	$(WATCOM_ENV) && $(CC) $(DEV_CFLAGS) -fo=$(DEV)/etemptst.obj $< && \
	  wlink option quiet system dos name $@ file $(DEV)/etemptst.obj

# TAILTST.EXE prints its command tail and environment, for
# tests/smoke-rt; built like ERR2OUT.EXE.
$(DEV)/TAILTST.EXE: tests/tools/tailtst.c $(TOOLS_ENV)
	$(WATCOM_ENV) && $(CC) -q -zq -ms -0 -bt=dos -I$$WATCOM/h \
	  -fo=$(DEV)/tailtst.obj $< && \
	  wlink option quiet system dos name $@ file $(DEV)/tailtst.obj

$(DEV)/ERR2OUT.EXE: tests/tools/err2out.c $(TOOLS_ENV)
	$(WATCOM_ENV) && $(CC) -q -zq -ms -0 -bt=dos -I$$WATCOM/h \
	  -fo=$(DEV)/err2out.obj $< && \
	  wlink option quiet system dos name $@ file $(DEV)/err2out.obj

test: $(DEV)/PERL.EXE $(TEST_TOOLS)
	BUILD=dev perl tests/run-dos $(DEV)/PERL.EXE tests/smoke
	perl tests/run-install $(DEV)/PERL.EXE $(TEST_TOOLS)

test-t: $(DEV)/PERL.EXE $(UPSTREAM)/.git-tree
	perl tests/run-t $(DEV)/PERL.EXE $(UPSTREAM) tests/t-baseline.txt

# The t/ suite under the runtime build, against the same baseline.
test-t-rt: $(RT)/PERL.EXE $(UPSTREAM)/.git-tree
	WORK=build/run-t-rt perl tests/run-t $(RT)/PERL.EXE $(UPSTREAM) \
	  tests/t-baseline.txt

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

.PHONY: all rt test test-rt test-t test-t-rt variants measure audit reference clean
