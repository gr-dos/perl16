# perl16 — Design Document

**Status:** Draft for review  
**Date:** 2026-10-26  
**Target:** Perl 3.044, 16-bit real-mode MS-DOS / compatible DOS

## 1. Summary

`perl16` will modernize the historical 16-bit MS-DOS port of Perl 3.044 for reproducible builds using Open Watcom and eventual inclusion as an independently licensed component in a GR-DOS distribution. It will support 8086/8088-class systems, DOS 3.0 or later, relocatable installation, and execution without a DOS extender.

The project will **permit development and testing builds that link Open Watcom's runtime**, but **must not publish any release binaries containing Open Watcom runtime components**. Reuse the existing `libc16` code where possible; consider a separate, optional `libkitchen16` only after measuring actual runtime dependencies.

## 2. Goals

1. Build and run Perl 3.044 as a native 16-bit DOS executable, targeting the 8086/8088 instruction set.
2. Preserve Perl 3 behavior as far as practical, rather than creating a new language implementation.
3. Support DOS 3.0+ (DOS 2.x compatibility is explicitly out of scope).
4. Allow installation in any directory on any available drive, with no hard-coded drive or installation root.
5. Derive the default `@INC` library directory from the location of the running executable.
6. Build reproducibly from a modern development system using Open Watcom and automated tests.
7. Ultimately ship binaries that contain no Open Watcom C runtime or other incompatible bundled runtime code.
8. Preserve license notices and meet the redistribution requirements of Perl 3 and all included code.

## 3. Non-goals

- Supporting Perl 1, Perl 2, or upgrading the language to Perl 4/5.
- DOS 2.x or earlier.
- Protected-mode DOS extenders, 386-only instruction sets, or a 32-bit build as the release target.
- XS, Perl 5 modules, or binary extension loading.
- Full Unix process semantics where DOS cannot provide them (`fork`, Unix signals, sockets, etc.).
- Implementing every feature of a full hosted C library in `libc16`.
- Shipping development binaries linked against the Open Watcom runtime.

## 4. Baseline and historical reference

Use the official Perl repository tag `perl-3.044` as the authoritative starting point. Its `msdos/` sources, Makefile and configuration are the primary historical DOS-port reference. Inspect the external `dospatch44` maintenance patch and apply only changes needed that are absent from the official tag. Preserve a clear record of locally applied changes.

The historical MS-DOS build used Microsoft C 5.1 and a large memory model. Whether all current sources build directly under Open Watcom, which compiler switches and compatibility shims are needed, and the precise source-level runtime dependencies remain investigation items.

## 5. Platform and installation contract

**CPU:** Intel 8086/8088 compatible or later.  
**OS:** DOS 3.0 or later, including compatible DOS implementations.  
**Binary:** 16-bit real-mode `.EXE`; no DOS extender.  
**Memory model:** Large model is the initial candidate, subject to build validation.  
**Memory:** Conventional-memory target; measure actual minimum and representative usage before setting a documented RAM requirement.

Proposed install tree:

```text
X:\SOME\OTHER\PERL\
    PERL.EXE
    GLOB.EXE      (if retained as a separate helper)
    LIB\
        ...
```

Default library lookup should include `<directory containing PERL.EXE>\LIB`, without requiring `PERLLIB`, environment setup, a particular drive letter, or a current directory. Existing `-I` behavior should be preserved. Keep `.` in the default search path if consistent with Perl 3 behavior. Test how additional paths (if any) are inserted and maintain a documented precedence.

### 5.1 Executable pathname resolution

Prefer the executable pathname recorded in the DOS 3.x process environment block (obtained using the PSP environment-segment pointer), after checking that its expected format is available and valid. Do not assume `argv[0]` is a fully qualified pathname; a limited fallback is acceptable for environments with missing or malformed path metadata. Avoid building an elaborate universal path resolver for unusual shells.

This should support all of the following, assuming the DOS loader successfully starts the program:

| Command invoked while C: is current | Expected `@INC` library root |
|---|---|
| `perl` found in `PATH` on `X:` | `X:\...\PERL\LIB` |
| `X:\SOME\OTHER\PERL\PERL.EXE` | `X:\SOME\OTHER\PERL\LIB` |
| `X:PERL.EXE` with X:'s current directory set appropriately | `<X: current directory>\LIB` |
| `\PERL\PERL.EXE` | `C:\PERL\LIB` |
| Relative directory invocation, such as `TOOLS\PERL.EXE` | Resolved executable directory plus `\LIB` |

DOS drive-relative paths such as `X:PERL.EXE` must retain their DOS meaning (current directory **on X:**), rather than being treated as `X:\PERL.EXE`. Determine whether path resolution requires any normalization in practice. Ensure drive and directory separators are handled without assuming Unix paths.

Also inspect `-P` preprocessing and any other use of `PRIVLIB`, so they use the same derived library path where appropriate.

## 6. Runtime architecture

```text
perl16
  |-- Perl 3.044 interpreter and DOS adaptations
  |-- libc16            (existing core runtime)
  `-- libkitchen16      (optional, only if investigation justifies it)
           `-- libc16
```

**`libc16`:** Maintain a lightweight reusable runtime for smaller GR-DOS programs. Avoid making it depend on optional heavyweight components.

**`libkitchen16` (provisional):** Optional library for costly or complex C facilities needed by substantial applications. `printf`/`sprintf` families, extended stdio, numeric conversions, or other features are **candidates**, not agreed implementation requirements. Keep it generic, not Perl-specific, and only create it if the audit shows a coherent reusable need.

**Perl-specific code:** Keep OS integration and interpreter-specific shims in `perl16`, preferentially under `msdos/`. Avoid putting Perl-specific behavior into generic libraries.

### 6.1 Runtime investigation

Determine actual direct C-library calls, implicit compiler helpers, startup requirements, library and allocator assumptions, and floating-point support. Inspect Perl's own formatting code (`do_sprintf` and related paths) before deciding whether or how much C formatted I/O to implement.

Build maps and linker diagnostics should identify dependencies on:

- Startup/termination and command-line/environment support.
- Segmented memory allocation and memory-model-aware operations.
- Basic and buffered file I/O and filesystem functions.
- Formatting, string conversion, and character/string operations.
- Floating-point arithmetic and compiler-generated arithmetic helpers.
- DOS-specific process and signal shims.

Do not mix incompatible allocator/`FILE` implementations or assume every unresolved symbol should be implemented in `libc16`. Size optimizations are desirable but secondary to correctness and licensing independence.

## 7. Build strategy and milestones

### M0 — Source and build audit
- Check out `perl-3.044` and inspect `msdos/` and `dospatch44`.
- Inventory compiler flags, generated sources, helper programs, and runtime dependencies.
- Establish Linux-hosted reproducible build tooling and test harness.

### M1 — Exploratory Watcom build (internal only)
- Make a 16-bit, 8086-compatible Open Watcom build using its stock runtime if necessary.
- Demonstrate interpreter startup and representative scripts under a DOS emulator.
- Record code size, conventional-memory use, stack/heap behavior, linker map, and known limitations.
- **Do not publish executable artifacts as releases.** Development binaries must remain clearly identified as non-release test output.

### M2 — Core functionality and relocation
- Test language basics: scalars, arrays, hashes, control flow, subroutines, regex, text/binary file operations, `require`, `-I`, `-e`, and exit statuses.
- Implement DOS 3.x executable-path-based default `@INC`.
- Test different install drives, `PATH`, absolute and drive-relative invocations, and invocation from unrelated current directories.
- Review `GLOB.EXE` and preprocessing behavior.

### M3 — Runtime migration
- Reuse available `libc16` functionality.
- Identify missing runtime symbols and compiler support code.
- Decide whether to create `libkitchen16` from evidence; design small reusable interfaces and independent tests if needed.
- Transition subsystems in coherent units; compare behavior to the M1 reference build.

### M4 — Runtime-independent release candidate
- Link using only code with reviewed, compatible redistribution terms.
- Inspect linker maps and build inputs; disallow automatic fallback to Watcom runtime libraries.
- Validate all executables, including helpers, under the same policy.
- Pass tests on an 8088/8086 emulator and, where practical, physical hardware.
- Prepare licensing, source, build instructions, and package layout.

## 8. Publication and licensing policy

- **Hard release gate:** No binaries that include Open Watcom runtime objects, startup modules, helper routines, or other unapproved runtime code may be published as release artifacts.
- Open Watcom's compiler/linker may be used as build tools. Runtime independence must be verified at link-input/object level, not inferred merely from the executable running successfully.
- Development/test builds using the Watcom runtime are permitted; keep them out of distributable release channels.
- `perl16` retains Perl 3.044's historical licensing, with notices and applicable complete corresponding source/distribution obligations. Determine final package obligations by checking the exact source and any imported components before shipping.
- `libc16` and any `libkitchen16` should retain their own intended compatible licenses; independently authored or appropriately licensed implementations only.
- Include notices, license files, build provenance, change records and the means to obtain corresponding source with the eventual GR-DOS package.
- The release gate is a project policy prompted by licensing concerns, not a legal determination about every possible Open Watcom distribution scenario.

## 9. Verification and acceptance criteria

A release candidate must demonstrate:

1. An actual 16-bit DOS executable that works on an emulated 8088/8086, without a DOS extender or 386 instructions.
2. Repeatable build instructions for a supported modern host.
3. Interpreter smoke tests, plus meaningful Perl 3 regression coverage and DOS-specific tests.
4. `require` finding a module under executable-relative `LIB` when the current drive is different.
5. Correct behavior when invoked through `PATH`, by absolute path, by root-relative path on the current drive, and by drive-relative path `X:PERL.EXE`.
6. No need for `PERLLIB` for ordinary installations; preserve `-I` behavior.
7. Documented memory requirements and failure behavior under low-memory conditions.
8. Verified clean linking of `PERL.EXE` and every distributed helper, with no prohibited runtime components.
9. Complete and reviewed source/license notices and release package metadata.

## 10. Open investigations (not yet design decisions)

- Exact Perl 3.044 external symbol/dependency inventory; amount of libc formatting Perl really uses.
- Whether and how `libkitchen16` should exist, including its actual API and repository arrangement.
- Whether the historical patch is needed on the official tag, and whether `GLOB.EXE` must be distributed.
- Open Watcom code-generation helper requirements and strategy for runtime-independent startup, stack handling and software floating point.
- Reliable executable-path API/PSP environment parsing under the target DOS variants, and behavior if that metadata is unavailable.
- Memory footprint, necessary compiler memory model, maximum script size, and practical RAM minimum.
- Precise treatment of Unix-like features under DOS and representative regression suite scope.
- Correct SPDX/license metadata, and licensing of any helper code added during porting.

## 11. References

- Perl historical source: https://github.com/Perl/perl5/tree/perl-3.044
- Perl 3 DOS-port archive: https://www2.dmst.aueb.gr/dds/sw/ports/dosperl/
- DOS maintenance patch: https://www2.dmst.aueb.gr/dds/sw/ports/dosperl/dospatch44
- Open Watcom compiler documentation: https://open-watcom.github.io/open-watcom-v2-wikidocs/cpguide.html
- Open Watcom licensing/relicensing background: https://github-wiki-see.page/m/open-watcom/open-watcom-v2/wiki/Relicensing-effort

---

*Draft for technical review. Historical source details and compatibility claims remain subject to verification by the M0 investigation.*
