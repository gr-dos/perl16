# M4: the release gate and checklist

What must be true before any perl16 binary is published (DESIGN.md,
section 8; issue #28), how perl16 checks it, and what is still open. No
release candidate or binary may be published until every item in
section 2 is done and `make release-check` passes on the exact build to
be published.

## 1. `make release-check`

`scripts/release-check PERL.EXE perl.map OBJECT...` runs every check.
It fails if any one fails:

1. **The pinned archives.**
   - `build/libc16.zip` and `build/libkitchen16.zip` must have the
     SHA-256 pinned in `scripts/fetch-libc16` and
     `scripts/fetch-libkitchen16`.
   - The unpacked files that the link and the checks read must be the
     archive's byte for byte: the large-model library, `VERSION`,
     `LICENSE`, `docs/LICENSE-PROVENANCE.md` and `docs/AUDIT.txt`.
2. **`scripts/check-link`.** Every module in the map must come from
   perl16's objects, `LIBC16L.LIB` or `LIBK16L.LIB`. No other library
   may be used, and no object may carry a default-library record. This
   is an independent check, kept as it is (M3-REPORT.md, section 3).
3. **`scripts/check-provenance --release`.** Every linked library
   module must be named by a row of its library's Modules table, and
   every row naming it must record an approved human review (section
   3). A module documented only in prose, one with review pending, or
   one missing altogether fails.
4. **No Open Watcom text in `PERL.EXE`.** No `Open Watcom`, `Watcom` or
   `Sybase` string may appear. The development build carries Open
   Watcom's copyright notice; the runtime build has none.
5. **The map is `PERL.EXE`'s.**

Tests:
- `tests/provenance/run` (12 cases, run by `make test`) exercises check
  3's checker with passing and deliberately failing records.
- `tests/link/run` (6 cases) does the same for check 2.
- Against the development build, `release-check` also fails checks 2
  and 4.
- A provenance file changed from the archive's fails check 1.

The build and `make test` don't run `release-check`, so development
builds stay usable while reviews are outstanding. CI runs it in the
`test` job as a step that may fail, and prints the result. A release
workflow, when there is one, must run it as a step that may not.

**Today it fails, as it should**, only on check 3:
- none of the 101 libc16 modules and 36 libkitchen16 modules in a
  table row has a recorded review;
- libc16's `systeme` and `envblock` have no row.

## 2. #28's items

| Item | State | Who |
|---|---|---|
| Rows for libc16's `systeme` and `envblock` | drafted (M4-PROVENANCE-REVIEW.md, section 4); to be added to libc16's table | libc16 |
| Human review of each linked libc16 module, recorded in libc16's provenance file | the worksheet lists the 24 rows and 2 prose-only members (M4-PROVENANCE-REVIEW.md) | **human reviewer**, in libc16 |
| The same for libkitchen16 | the worksheet lists its 5 rows | **human reviewer**, in libkitchen16 |
| MIT notices, third-party attribution, compatibility with Perl 3.044 | analysed in section 4; the package must carry the notices and source of section 5 | **human decision** on section 4; perl16's own license |
| The release gate: a row and a recorded review for every linked member, failing, not warning | done: `check-provenance --release`, `make release-check` | perl16 (this branch) |
| `check-link` kept, and the checker exercised with passing and failing fixtures | done: `tests/link/run`, `tests/provenance/run` | perl16 (this branch) |
| Rerun against the exact pinned archives; a new pin's SHA-256 recorded and verified | done for today's pins (check 1); to be rerun after each re-pin (section 6) | perl16, at each re-pin |
| The evidence and remaining constraints in an M4 report or checklist | this file and M4-PROVENANCE-REVIEW.md | perl16 (this branch) |

## 3. How a review is recorded

`check-provenance` reads a row of a library's Modules table as
reviewed when:
- the table has a column headed **Review** (or **Human review**);
- the row's cell in it begins `approved by NAME, YYYY-MM-DD`;
- none of the row's columns still says "human review pending".

Free text such as "as above", or a date without a name, doesn't count.
A member counts as reviewed only when every row naming it is approved:
its own row and every row that changes it.

The Review column doesn't exist yet in either library. Adopting it is a
change to both libraries' provenance format. If the libraries prefer
another form, `read_provenance` in `scripts/check-provenance` and the
fixtures in `tests/provenance` change with it.

## 4. Licenses and notices

**This is an analysis for review, not a legal determination**
(DESIGN.md, section 8).

| Component in `PERL.EXE` | License | What it asks of a binary distribution |
|---|---|---|
| Perl 3.044, Larry Wall; the MS-DOS port, Diomidis Spinellis | GPL-1.0-or-later (`README`, `Copying`) | the copyright notices and the GPL text with the binary (GPL v1, sections 1 and 3); the complete corresponding source, or a written offer valid for three years (section 3a or 3b) |
| perl16's patches and `msdos/` | **not yet chosen** (README.md; M0-AUDIT.md, section 3) | must be GPL-compatible, since `PERL.EXE` is a work based on Perl |
| libc16 0.15 | MIT, "Copyright (c) 2026 Graham Ollis" (`LICENSE`) | the copyright and permission notice in all copies or substantial portions; MIT is compatible with the GPL |
| libkitchen16 0.02 | MIT, same notice | the same |
| the parser, `perl.c` from Bison 3.8.2 | the grammar's terms, by Bison's skeleton exception (M0-AUDIT.md, section 3) | nothing beyond Perl's |

**Findings:**
- **The libraries' source counts as corresponding source.** GPL v1
  section 3 defines the complete source of an executable as "all the
  source code for all modules it contains". Its exception is for
  standard libraries that accompany the operating system, and libc16
  and libkitchen16 don't. So the source offered with a binary includes
  both libraries' source at the pinned releases, not only Perl's and
  perl16's. MIT allows that.
- **No third-party code is recorded in a linked module.** Both records
  name their sources as specs, public standards and documentation, and
  their own experiments.
  - libkitchen16's `model.inc` is copied from libc16 (MIT, same
    holder). It is an include file, not a member.
  - Tools whose licenses differ are build or test tools only: Open
    Watcom (Sybase Open Watcom Public License), JWasm and DOSBox-X
    (GPL-2.0).
  - Open Watcom's translator comment is in the libraries' C objects but
    not in linked programs (libc16's record). Check 4 confirms that
    `PERL.EXE` has no Open Watcom text.
- **AI authorship.** Both records state that material generated purely
  by an AI may not be protected by copyright, and that nothing in them
  restricts redistribution of it. That doesn't restrict distribution
  under the GPL, but the reviewer should confirm that reading.
- **Perl's README note.** Perl's README gives Larry Wall's
  interpretation that scripts and certain linked object code don't fall
  under the GPL. It doesn't change what a binary of the interpreter
  itself needs.

**Decisions for a human:**
1. perl16's own license (README.md says it is not yet decided). It must
   be GPL-compatible. Any choice that is applies to the patches and
   `msdos/`.
2. How the source is provided: in the release (GPL v1 3a), or by a
   written offer (3b). The first is simpler for a small DOS package.
3. Whether the analysis above is right.

## 5. The package (to do in M4)

A release package, built from a tag, carries:
- `PERL.EXE`, with `make release-check` passing on that build;
- the `LIB` files, from Perl 3.044's `lib/`;
- the GPL text (`Copying`), Perl's `README` notices, and libc16's and
  libkitchen16's `LICENSE`;
- `docs/DOS.md` or a text version of it;
- the corresponding source (section 4):
  - Perl 3.044 at tag `perl-3.044`;
  - `patches/`, `msdos/` and the build;
  - libc16 and libkitchen16 at their pinned release tags.

No such workflow exists yet. When it is written, it runs `make`, `make
test`, `make test-t` and `make release-check`, and publishes nothing if
any of them fails.

## 6. Re-pinning after a provenance correction

A library correction, such as libc16's new rows or a Review column,
needs a new library release. perl16 then:
1. Sets `version` and `sha256` in `scripts/fetch-libc16` or
   `scripts/fetch-libkitchen16` to the release's published `.sha256`
   asset (libc16's `docs/CONSUMERS.md`, "Using libc16").
2. Runs `make`, `make test` and `make test-t`.
3. Runs `make release-check`. Check 1 verifies the archive against the
   new pin and reads the provenance from that archive.
4. Runs `make provenance-worksheet` to refresh M4-PROVENANCE-REVIEW.md,
   and records the new SHA-256 in docs/PROVENANCE.md.

Today's pins:
- libc16 0.15:
  `042b6d2d18c381592cc929523835a695d7b2955a606bf44df6b2a43727f0d287`
- libkitchen16 0.02:
  `2ca356b7d2a23442b7851b10c09cfa577ee3888eaf5b4b899f10ee494162cb85`
