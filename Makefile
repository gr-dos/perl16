# perl16: Perl 3.044 for 16-bit MS-DOS, built with Open Watcom
# (docs/DESIGN.md).
#
#   make             build/rt/PERL.EXE, linked with libc16 and libkitchen16
#                    alone (the runtime build, M3.4; below); check-link
#                    refuses any other runtime
#   make test        tests of build/rt/PERL.EXE under DOSBox-X, on an
#                    emulated 8086: check-link's own (tests/link), the
#                    smoke tests and the runtime build's own
#                    (tests/run-dos), and tests of it installed on other
#                    drives and directories (tests/run-install)
#   make test-t      Perl 3.044's own t/ suite under DOSBox-X, checked
#                    against tests/t-baseline.txt (tests/run-t)
#   make release-check  the release gate: pinned archives, check-link,
#                    reviewed provenance for every linked library module
#                    (scripts/release-check; docs/M4-RELEASE.md)
#   make provenance-worksheet  refresh docs/M4-PROVENANCE-REVIEW.md
#   make dev         build/dev/PERL.EXE, the development build with Open
#                    Watcom's runtime (M1 and M2; below)
#   make test-dev    the smoke and installation tests of build/dev/PERL.EXE
#   make test-t-dev  the t/ suite under build/dev/PERL.EXE
#   make variants    the M1 experimental builds in build/var (below),
#                    and FREEMEM.EXE and TICKS.EXE for the probes
#                    (scripts/build-variant, tests/tools)
#   make measure     the M1 stack and memory measurements of the variants
#                    (scripts/stack-probe, scripts/mem-probe;
#                    docs/M1-REPORT.md)
#   make audit       runtime inventory of the development build's objects:
#                    build/audit/report.txt (scripts/audit-externals),
#                    and of its sources recompiled against libc16's and
#                    libkitchen16's headers and linked with both
#                    libraries: build/audit/libc16/report.txt
#                    (scripts/audit-libc16; docs/M3-RUNTIME-AUDIT.md)
#   make reference   fetch the historical MS-DOS port material into
#                    build/reference (not needed to build)
#   make clean       remove build products; keep downloads and tools
#
# build/dev/PERL.EXE, the build/var variants and the test tools linked
# with Open Watcom's C runtime (ERR2OUT.EXE, TAILTST.EXE) are development
# and test binaries only and must never be published (docs/DESIGN.md,
# section 8). No binary is published before M4's release candidate.
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

# Development build (make dev; M1 and M2, kept as the reference the
# runtime build is compared with): large model, 8086 instructions, Open
# Watcom's headers and runtime. -zc puts string literals in the code
# segment; without it DGROUP overflows (docs/M0-AUDIT.md, section 6).
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

# Runtime build (the default; M3.4, #16 and #17; docs/M3-REPORT.md and
# docs/M3-RUNTIME-AUDIT.md, section 11.7): the same sources compiled as
# a libc16 and libkitchen16 consumer is, and linked with their libraries
# instead of Open Watcom's runtime.
# -zl -zld -x keep Open Watcom's headers and library records out, -fpc
# makes floating point calls to libkitchen16's helpers, and msdos/p16rt.h,
# force-included, puts every library prototype in scope (P16_RT).
# -wx shows every warning; each module's go to its .err file beside the
# object, and scripts/check-w131 fails the build on W131 (no prototype)
# for a function of either library (#16). libkitchen16 comes first, in
# the include path and the link. RT_NAMES are perl16's for this build
# alone: environ and the exec family, which libc16 doesn't have, the
# numeric tests -fpc gets wrong (p16fp.h), the INT 24h handler
# (harderr.c), and <ctype.h> as a table (ctype16.c); p16init.asm puts
# environ's set-up and the handler's in libc16's init table.
RT          := build/rt
RT_NAMES    = environ exec16 p16fp harderr ctype16
RT_CFLAGS   = -q -zq -zl -zld -x -ml -0 -fpc -zc -bt=dos -DMSDOS \
              -DCRIPPLED_CC -DP16_RT -fi=msdos/p16rt.h -wx -I$(SRC) -Imsdos \
              -I$(LIBKITCHEN16_DIR)/include -I$(LIBC16_DIR)/include
RT_AFLAGS   = $(DEV_AFLAGS) -dP16_RT
RT_OBJS     = $(RT)/stk16.obj $(PERL_NAMES:%=$(RT)/%.obj) \
              $(PORT_NAMES:%=$(RT)/%.obj) $(P16_NAMES:%=$(RT)/%.obj) \
              $(RT_NAMES:%=$(RT)/%.obj) $(RT)/p16init.obj
# The stack (#17, docs/M3-RUNTIME-AUDIT.md, section 11.7): libc16's heap
# is outside DGROUP, so the stack takes what static data leave of it,
# but RT_DGROUP_MIN_FREE, so that more static data fails the link
# rather than overflowing DGROUP. STK16_MARGIN is the development
# build's 2 KB.
RT_STACK    ?= 53k
RT_DGROUP_MIN_FREE ?= 128
RT_LDOPTS   = option quiet, nodefaultlibs, stack=$(RT_STACK)
RT_SYMS     = $(RT)/libc16.lst $(RT)/libk16.lst
# Compile one module of the runtime build: wcc's output goes to the
# module's .err file, shown only if the compile fails, and that file is
# checked for library functions called without a prototype. make
# echoes only the compile.
RT_COMPILE  = rm -f $(@:.obj=.err) && $(WATCOM_ENV) && \
              { $(CC) $(RT_CFLAGS) -fr=$(@:.obj=.err) -fo=$@ $< >/dev/null 2>&1 \
                || { cat $(@:.obj=.err); exit 1; }; } && \
              { perl scripts/check-w131 $(RT_SYMS) -- $(@:.obj=.err) \
                || { rm -f $@; exit 1; }; }

# tests/run-install's DOS tools (below), for each build
RT_TEST_TOOLS  = $(RT)/EXETEST.EXE $(RT)/ETEMPTST.EXE $(DEV)/ERR2OUT.EXE
DEV_TEST_TOOLS = $(DEV)/EXETEST.EXE $(DEV)/ETEMPTST.EXE $(DEV)/ERR2OUT.EXE

PATCHES     = $(sort $(wildcard patches/*.patch))

all: $(RT)/PERL.EXE

dev: $(DEV)/PERL.EXE

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

# A unit test of exec16.c's execl(), which only the runtime build has,
# linked like it. Never to be published.
EXECLTST_OBJS = $(RT)/execltst.obj $(RT)/stk16.obj $(RT)/exec16.obj \
  $(RT)/environ.obj $(RT)/p16init.obj $(RT)/harderr.obj

$(RT)/EXECLTST.EXE: $(EXECLTST_OBJS) $(LIBC16L) $(LIBK16L) $(TOOLS_ENV)
	$(WATCOM_ENV) && wlink $(RT_LDOPTS) format dos name $@ \
	  $(EXECLTST_OBJS:%=file %) library $(LIBK16L) library $(LIBC16L)

# CTYPETST.EXE: ctype16.h's macros against libc16's functions (#17).
CTYPETST_OBJS = $(RT)/ctypetst.obj $(RT)/stk16.obj $(RT)/ctype16.obj

$(RT)/CTYPETST.EXE: $(CTYPETST_OBJS) $(LIBC16L) $(LIBK16L) $(TOOLS_ENV)
	$(WATCOM_ENV) && wlink $(RT_LDOPTS) format dos name $@ \
	  $(CTYPETST_OBJS:%=file %) library $(LIBK16L) library $(LIBC16L)

$(RT)/ctypetst.obj: tests/tools/ctypetst.c $(P16_HEADERS) $(RT_SYMS) \
  $(TOOLS_ENV) scripts/check-w131 Makefile
	@echo "$(CC) $(RT_CFLAGS) -fo=$@ $<"
	@$(RT_COMPILE)

# HARDTST.EXE, a unit test of the INT 24h handler (#17), started like
# PERL.EXE (p16init.obj installs the handler).
HARDTST_OBJS = $(RT)/hardtst.obj $(RT)/stk16.obj $(RT)/harderr.obj \
  $(RT)/environ.obj $(RT)/p16init.obj

$(RT)/HARDTST.EXE: $(HARDTST_OBJS) $(LIBC16L) $(LIBK16L) $(TOOLS_ENV)
	$(WATCOM_ENV) && wlink $(RT_LDOPTS) format dos name $@ \
	  $(HARDTST_OBJS:%=file %) library $(LIBK16L) library $(LIBC16L)

$(RT)/hardtst.obj: tests/tools/hardtst.c $(P16_HEADERS) $(RT_SYMS) \
  $(TOOLS_ENV) scripts/check-w131 Makefile
	@echo "$(CC) $(RT_CFLAGS) -fo=$@ $<"
	@$(RT_COMPILE)

# FPCTST.EXE, the C layer of tests/smoke-rt/fpcmp.pl (#16): the
# compiler's comparisons and p16fp.h's, compiled like the runtime build.
FPCTST_OBJS = $(RT)/fpctst.obj $(RT)/stk16.obj $(RT)/p16fp.obj

$(RT)/FPCTST.EXE: $(FPCTST_OBJS) $(LIBC16L) $(LIBK16L) $(TOOLS_ENV)
	$(WATCOM_ENV) && wlink $(RT_LDOPTS) format dos name $@ \
	  $(FPCTST_OBJS:%=file %) library $(LIBK16L) library $(LIBC16L)

$(RT)/fpctst.obj: tests/tools/fpctst.c $(P16_HEADERS) $(RT_SYMS) \
  $(TOOLS_ENV) scripts/check-w131 Makefile
	@echo "$(CC) $(RT_CFLAGS) -fo=$@ $<"
	@$(RT_COMPILE)

# EXETEST.EXE and ETEMPTST.EXE, tests/run-install's unit tests of
# exepath.c and etemp.c, compiled and linked like the runtime build.
EXETEST_OBJS = $(RT)/exetest.obj $(RT)/stk16.obj $(RT)/exepath.obj \
  $(RT)/ctype16.obj
ETEMPTST_OBJS = $(RT)/etemptst.obj $(RT)/stk16.obj $(RT)/ctype16.obj

$(RT)/EXETEST.EXE: $(EXETEST_OBJS) $(LIBC16L) $(LIBK16L) $(TOOLS_ENV)
	$(WATCOM_ENV) && wlink $(RT_LDOPTS) format dos name $@ \
	  $(EXETEST_OBJS:%=file %) library $(LIBK16L) library $(LIBC16L)

$(RT)/ETEMPTST.EXE: $(ETEMPTST_OBJS) $(LIBC16L) $(LIBK16L) $(TOOLS_ENV)
	$(WATCOM_ENV) && wlink $(RT_LDOPTS) format dos name $@ \
	  $(ETEMPTST_OBJS:%=file %) library $(LIBK16L) library $(LIBC16L)

$(RT)/exetest.obj: tests/tools/exetest.c $(P16_HEADERS) $(RT_SYMS) \
  $(TOOLS_ENV) scripts/check-w131 Makefile
	@echo "$(CC) $(RT_CFLAGS) -fo=$@ $<"
	@$(RT_COMPILE)

$(RT)/etemptst.obj: tests/tools/etemptst.c msdos/etemp.c $(P16_HEADERS) \
  $(RT_SYMS) $(TOOLS_ENV) scripts/check-w131 Makefile
	@echo "$(CC) $(RT_CFLAGS) -fo=$@ $<"
	@$(RT_COMPILE)

$(RT)/execltst.obj: tests/tools/execltst.c $(P16_HEADERS) $(RT_SYMS) \
  $(TOOLS_ENV) scripts/check-w131 Makefile
	@echo "$(CC) $(RT_CFLAGS) -fo=$@ $<"
	@$(RT_COMPILE)

# check-dgroup with RT_DGROUP_MIN_FREE, not DGROUP_MIN_FREE: libc16's
# large-model heap grows the program's memory block above the stack,
# outside DGROUP, and a child needs none of DGROUP (Open Watcom's spawn
# needed near heap).
# check-link (docs/DESIGN.md, section 8): every module in the map comes
# from RT_OBJS or the two libraries, and no object asks for a default
# library, so nothing of Open Watcom's runtime can be linked in.
# check-provenance: every library module linked has an entry in its
# library's docs/LICENSE-PROVENANCE.md, the libraries' release gate.
$(RT)/PERL.EXE: $(RT_OBJS) $(LIBC16L) $(LIBK16L) $(TOOLS_ENV) \
  scripts/check-dgroup scripts/check-link scripts/check-provenance \
  Makefile
	$(WATCOM_ENV) && wlink $(RT_LDOPTS), map=$(RT)/perl.map \
	  format dos name $@.tmp $(RT_OBJS:%=file %) \
	  library $(LIBK16L) library $(LIBC16L)
	perl scripts/check-dgroup $(RT)/perl.map $(RT_DGROUP_MIN_FREE)
	@perl scripts/check-link $(RT)/perl.map $(RT_OBJS) $(LIBK16L) $(LIBC16L)
	perl scripts/check-provenance $(RT)/perl.map $(LIBK16L) $(LIBC16L)
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
	@echo "$(CC) $(RT_CFLAGS) -fo=$@ $<"
	@$(RT_COMPILE)

$(RT)/%.obj: msdos/%.c $(P16_HEADERS) $(RT_SYMS) $(TOOLS_ENV) \
  scripts/check-w131 Makefile
	mkdir -p $(RT)
	@echo "$(CC) $(RT_CFLAGS) -fo=$@ $<"
	@$(RT_COMPILE)

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
# like PERL.EXE (the runtime build's are above, with the other test
# tools), and ERR2OUT.EXE, which lets a test see standard error. Like
# PERL.EXE, never to be published. (DEV_TEST_TOOLS and RT_TEST_TOOLS are
# set with the other variables, above.)

$(DEV)/EXETEST.EXE: tests/tools/exetest.c $(DEV)/exepath.obj $(P16_HEADERS) \
  $(TOOLS_ENV)
	$(WATCOM_ENV) && $(CC) $(DEV_CFLAGS) -fo=$(DEV)/exetest.obj $< && \
	  wlink option quiet system dos name $@ file $(DEV)/exetest.obj \
	  file $(DEV)/exepath.obj

$(DEV)/ETEMPTST.EXE: tests/tools/etemptst.c msdos/etemp.c $(P16_HEADERS) \
  $(TOOLS_ENV)
	mkdir -p $(DEV)
	$(WATCOM_ENV) && $(CC) $(DEV_CFLAGS) -fo=$(DEV)/etemptst.obj $< && \
	  wlink option quiet system dos name $@ file $(DEV)/etemptst.obj

# TAILTST.EXE prints its command tail and environment, for
# tests/smoke-rt, and ERR2OUT.EXE runs a command with standard error on
# standard output. Both are small-model test tools with Open Watcom's
# runtime, which both builds' tests use; they are never distributed
# (docs/M3-REPORT.md, section 6).
$(DEV)/TAILTST.EXE: tests/tools/tailtst.c $(TOOLS_ENV)
	mkdir -p $(DEV)
	$(WATCOM_ENV) && $(CC) -q -zq -ms -0 -bt=dos -I$$WATCOM/h \
	  -fo=$(DEV)/tailtst.obj $< && \
	  wlink option quiet system dos name $@ file $(DEV)/tailtst.obj

$(DEV)/ERR2OUT.EXE: tests/tools/err2out.c $(TOOLS_ENV)
	mkdir -p $(DEV)
	$(WATCOM_ENV) && $(CC) -q -zq -ms -0 -bt=dos -I$$WATCOM/h \
	  -fo=$(DEV)/err2out.obj $< && \
	  wlink option quiet system dos name $@ file $(DEV)/err2out.obj

# The tests (the runtime build's PERL.EXE, M3.4): check-link's own test,
# the smoke tests, tests/smoke-rt, the cases only the runtime build has
# (system() with %ENV, #22, with TAILTST.EXE; numeric comparisons, #16,
# with FPCTST.EXE; the INT 24h handler and the ctype table, #17, with
# HARDTST.EXE and CTYPETST.EXE), and the installation tests, EXECLTST.EXE
# among them.
test: test-link test-provenance $(RT)/PERL.EXE $(RT_TEST_TOOLS) $(RT)/EXECLTST.EXE \
  $(DEV)/TAILTST.EXE $(RT)/FPCTST.EXE $(RT)/HARDTST.EXE $(RT)/CTYPETST.EXE
	BUILD=rt perl tests/run-dos $(RT)/PERL.EXE tests/smoke
	WORK=build/run-dos-rt BUILD=rt \
	  FILES="$(DEV)/TAILTST.EXE $(RT)/FPCTST.EXE $(RT)/HARDTST.EXE \
	  $(RT)/CTYPETST.EXE" \
	  perl tests/run-dos $(RT)/PERL.EXE tests/smoke-rt
	perl tests/run-install $(RT)/PERL.EXE $(RT_TEST_TOOLS) $(RT)/EXECLTST.EXE

test-t: $(RT)/PERL.EXE $(UPSTREAM)/.git-tree
	perl tests/run-t $(RT)/PERL.EXE $(UPSTREAM) tests/t-baseline.txt

# The development build's tests, as in M2, in their own work directories.
test-dev: $(DEV)/PERL.EXE $(DEV_TEST_TOOLS)
	WORK=build/run-dos-dev BUILD=dev perl tests/run-dos $(DEV)/PERL.EXE \
	  tests/smoke
	WORK=build/run-install-dev perl tests/run-install $(DEV)/PERL.EXE \
	  $(DEV_TEST_TOOLS)

test-t-dev: $(DEV)/PERL.EXE $(UPSTREAM)/.git-tree
	WORK=build/run-t-dev perl tests/run-t $(DEV)/PERL.EXE $(UPSTREAM) \
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

# scripts/check-link against fixture maps (tests/link/run).
test-link:
	sh tests/link/run

# scripts/check-provenance against fixture records (tests/provenance/run).
test-provenance:
	sh tests/provenance/run

# The release gate (docs/M4-RELEASE.md, #28): the pinned archives, the
# link, reviewed provenance for every linked library module, and no Open
# Watcom text in PERL.EXE. It fails until every module's review is
# recorded; the build and the tests don't depend on it.
release-check: $(RT)/PERL.EXE scripts/release-check
	perl scripts/release-check $(RT)/PERL.EXE $(RT)/perl.map $(RT_OBJS)

# The reviewer's worksheet: every linked library module, by provenance
# row. It replaces section 5 of docs/M4-PROVENANCE-REVIEW.md, after the
# hand-written sections 1 to 4.
provenance-worksheet: $(RT)/PERL.EXE scripts/check-provenance
	perl scripts/check-provenance --worksheet $(RT)/perl.map $(LIBK16L) \
	  $(LIBC16L) | sed 's/^### /#### /; s/^## /### /' > $(RT)/worksheet.md
	perl -0pi -e 'BEGIN { local $$/; open my $$f, "<", "$(RT)/worksheet.md" or die; $$w = <$$f>; } s/(\n## 5\. The worksheet\n\n).*\z/$$1$$w/s or die "no section 5\n"' \
	  docs/M4-PROVENANCE-REVIEW.md

reference:
	sh scripts/fetch-reference build/reference

clean:
	rm -rf $(SRC) $(SRC).tmp $(DEV) build/var build/audit build/run-dos \
	  build/run-t build/stack-probe build/mem-probe

# The assembled sources are made by one rule; make must not delete them.
.SECONDARY:

.PHONY: all dev rt test test-t test-dev test-t-dev test-link test-provenance \
  release-check provenance-worksheet variants measure audit reference clean
