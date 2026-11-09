# Third-party notices

ForeverPlus ships with this file so that anyone holding a copy can see what is
in the package and under whose terms. Section 1 of `LICENSE` points here.

## Currently bundled

**Nothing.** Every file in the Addon was written for this project.

When that changes, this file lists each component before the release goes out,
and `build.ps1` refuses to package a `Libs/` folder without it.

## What may be bundled

Only **permissive** licenses: ones that allow a component to be included in a
work distributed under other terms, and ask for nothing beyond keeping their
notices intact:

- MIT
- BSD (2-clause, 3-clause, and the Ace3 variant)
- zlib / libpng
- Apache-2.0
- unambiguous public domain dedications (CC0, Unlicense)

## What may not be bundled, and why

- **GPL, in any version.** The combined work would have to be distributed
  under the GPL. That is the one thing that makes this project's own terms
  impossible, and it is the reason the rule exists at all.
- **LGPL.** Its relinking requirement has no clean meaning for a Lua addon
  shipped as a single package. Decided against on 2026-09-19: the ambiguity is
  not worth the convenience.
- **Anything whose license is unclear or contradicts itself.** The worked
  example is `LibSharedMedia-3.0`: the source comment says LGPL 2.1, while
  CurseForge and WowAce list it as All Rights Reserved, and the issue asking
  which one is true has been open since 2023 with no answer. A license you
  cannot state is a license you cannot ship.
- **Code from other addons**, however permissively they behave in practice.
  ElvUI is the reference for *design* in `ROADMAP.md` and for nothing else:
  its own code is all rights reserved, private modification only.

## Checked and cleared

Verified on 2026-09-19, kept here so the answer is not looked up twice:

| Component | License | Verdict |
|---|---|---|
| oUF | MIT | Usable. Attribution only |
| Ace3 | BSD-style | Usable. Keep the copyright notice, conditions and disclaimer. Its extra clause forbids redistributing a **standalone** copy without written permission from the Ace3 lead: embedding is the intended use, so it does not bite |
| LibSharedMedia-3.0 | contradictory | Not usable while it stays unclear |
| LibStub | treated as public domain across the ecosystem | Unconfirmed from a primary source. Check before embedding |
| LibSerialize | MIT | Usable. Attribution only. Read from the header of the copy WeakAuras ships on this client |
| LibDeflate | GPL-3.0-or-later | **Not usable.** Its own header says "GNU General Public License Version 3 or later", despite crediting zlib. Read from the copy WeakAuras ships. This closes the usual export route: LibSerialize plus LibDeflate plus Base64, which is what WeakAuras and DBM both do |

A component being on this list is a license verdict only. Whether it runs on
build 69913 is a separate question and gets measured before it is embedded.

## Format for an entry

When a component is added, it goes in under *Currently bundled* like this, with
the license text reproduced in full rather than linked: a link can rot, and
the obligation is to ship the notice:

```
### <name> <version>

Source: <url>
License: <SPDX identifier or name>

<the complete license text, verbatim>
```
