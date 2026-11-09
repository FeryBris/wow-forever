# SoTBookie — design specification (v1)

Status 2026-08-13 (night design run): research verified, ~90 user stories
consolidated (USER-STORIES.md), adversarial protocol review done (22 findings,
all folded in below; raw findings in review transcripts, key fixes marked F#).
This file is the implementation contract.

**Status 2026-08-18: 2-client smoke test PASSED end-to-end** (create, join/
switch/leave, lock, resolve+plan, settle, history, stats, login sync, announce).
SavedVariables diff of both clients: identical stores incl. epochs. Fixed during
the test: math.randomseed load-killer (26cb854), anonymous-frame template
textures (61f7911). Then same-day: Czech no-diacritics localization, payment
handshake + Dluhy tab (v0.9.1), row icon controls, close-button fix.

## v1.0.0 release record (2026-08-18)

UAT round 4 bugs — all fixed, UAT round 5 happy path passed on 2 clients:
1. Diacritics → ASCII transliteration in `W.SanitizeText` (dac6dc3).
2. Unlock toggle protocol — design U1–U5 below (26a84ea + 95b93c1 review
   hardening; adversarial review verdict: payment plan cannot diverge).
3. Lock control: 24 px stateful padlock toggle, pinned highlight (6744469).
4. Resolve confirm: custom dialog with announce checkbox (59ce1d0).
Plus UAT5 finding: 3.3.5 `GetAddOnMetadata` returns nil for Version →
`W.VERSION` hardcoded in Core.lua, keep in sync with the TOC (ea0fae6).

Release checks executed:
- README.md rewritten in Czech (no diacritics) for guildmates; notes that a
  FIRST install needs a full client restart (TOC scan at startup only).
- Exact-case audit of every file reference (TOC, embeds.xml, all Libs XML)
  and BOM scan of all text files: clean → safe for wine/mac case-sensitive
  setups.
- Zip built with `git archive` (forward-slash entries — PowerShell 5.1
  Compress-Archive writes backslash entry names that break unix unzip;
  never use it for release zips), no `.git`, `SoTBookie/` prefix. AGENTS.md/
  CLAUDE.md easter egg ships intentionally.
- Cross-version safety: unknown message types are ignored (forward compat),
  v0.9.x locked bets get `le` migrated at load, H version hint now actually
  works (was stuck at the 0.9.0 fallback).

Still open after ship: live multi-PC verify with Blueblack before wide
launcher distribution; collect feedback from the 2026-08-19 raid. UAT5 edge
steps the user skipped (stale-mirror unlock ordering, resolve-dialog
liveness, ESC double-close observation) ride along into raid feedback.

## Product summary

Guild betting board. A bet = statement + fixed gold stake. Two camps: YES
(agree with the statement; author auto-joins) and NO. Guildies with the addon
join/switch/leave one-click while the bet is open. Author locks (freeze),
cancels, or resolves (declares winning side). Losers' stakes pool and split
among winners; a deterministic payment plan (who pays whom) is shown
identically everywhere. Settlement is manual gold trading with soft local
checkboxes. History + net-gold leaderboard. Hidden GUILD addon comms; the only
visible chat output is a manual one-line Announce.

## Data model (SavedVariables `SoTBookieDB` via AceDB)

```
db.global.bets[id] = {
  id,                -- "Author-nonce-counter" (F11: nonce = per-char random
                     --  3-char base36 stored in db.char, regenerated on SV wipe)
  author,            -- character name (sender of N; never trusted from payload)
  text,              -- sanitized statement; serialization cost <= 100 (see Text)
  gold,              -- integer 1..1000000 (validated on input AND receive, F21)
  status,            -- "open" | "locked" | "cancelled" | "resolved"
  win,               -- nil | "Y" | "N" (set with resolved)
  created,           -- author's time() (DISPLAY ONLY, F10)
  firstSeen,         -- local time() at insert (drives expiry, F10)
  resolvedAt, resolvedBy,   -- paper trail (A4.15)
  p = { [name]="Y"|"N" },   -- participants
  pe,                -- participant epoch: 0 = creation-implicit {author=Y};
                     --  >0 = replaced by author snapshot with that epoch (F4/F9)
  le,                -- lock-toggle epoch: highest author open/locked transition
                     --  applied locally (0 = never locked). Shares the per-bet
                     --  counter with pe: author allocates max(pe,le)+1 per event,
                     --  so every K/U/resolve-snapshot epoch is unique (v1.0 U1).
                     --  Migration: v0.9.x locked bets get le = max(pe,1) at load
  my,                -- true once this character locally created/joined/left the
                     --  bet; while set, mirrors never alter my own p entry (a
                     --  local leave can't be revived). Absent after an SV wipe —
                     --  exactly when a mirror SHOULD restore my membership (U5)
  re,                -- epoch referenced by R; plan/stats valid iff pe == re
  incomplete,        -- true when status is locked/resolved but pe < required
}
db.global.aggregate = { [name] = {net, wins, losses, best} }
                     -- folded-in contributions of PRUNED resolved bets (F6)
db.char  = { nonce, counter, settled = { [betId] = { ["From>To"]=true } } }
db.profile = { minimap={hide}, autoLockOnCombat=false, newBetSound=false }
```

No `statted` table (F6): stats are derived on demand by folding
`db.global.aggregate` + every resolved+complete bet in `db.global.bets`.
Idempotency is structural; late participant corrections self-heal stats.

## State machine

Two layers since v1.0 (unlock support, U1–U4):

- **Terminal layer** `cancelled(2) / resolved(3)`: monotonic as before —
  merge adopts strictly higher rank, resolved wins over cancelled (money
  moved), nothing ever leaves a terminal status.
- **Toggle layer** `open ↔ locked`: NOT rank-ordered anymore. The author
  bumps the shared per-bet epoch on every transition (lock = K(e), unlock =
  U(e)) and peers apply the status carried by the highest epoch seen:
  `ApplyToggle(id, e, status)` applies iff local status is open/locked and
  `e >= le`, then sets `le = e` (equality only re-delivers the same event —
  epochs are unique per event — so duplicates stay idempotent) (U1).

Transitions (author-only unless noted): open↔locked (toggle, epoch-ordered),
open→cancelled, locked→cancelled, locked→resolved, open→resolved (client
auto-sends lock first). R is applied from ANY non-terminal local status (F2).
A stale K/U (epoch < le) is ignored — a peer that saw lock(4)+unlock(5) can
never be re-locked by a replayed or mirror-fed lock(4) (U2).

**Expiry (F10)**: open/locked bets with `firstSeen < now − 72h` RENDER as
EXPIRED (cancelled semantics, grey). Render-only — stored status never
mutates, so a late R still wins. Expired bets are EXCLUDED from sync
selection (a peer inserting one with a fresh firstSeen would resurrect it)
and become prunable one week after firstSeen; until then they stay so a
very late resolve still finds its bet.

**Prune**: resolved/cancelled beyond 50 (oldest first), skipping bets where
the LOCAL CHARACTER is in `p` with unchecked payments (F15 — participant
check prevents alts blocking prune forever). Before deletion, fold the bet's
stat contribution into `db.global.aggregate` (F6).

## Wire protocol

AceComm-3.0, prefix `"Bkie"` (4 chars ⇒ 250-byte single-part budget; the real
budget is 255 − prefix − 1, and multipart appends a marker byte — we treat
**245 as the hard cap** and never multipart). Payload = AceSerializer table,
single-letter keys. Every send passes `assert(#serialized <= 245)`; on
violation: log locally + do NOT send (F5 — an oversized send would multipart
and interleave-corrupt the per-sender spool). Unknown `t` → ignore (F20-adjacent
forward compat). All handlers ignore `sender == UnitName("player")` EXCEPT the
echo watchdog (below). Timestamps travel as offsets from epoch 1754000000 (F7).
`status` travels as one char o/l/c/r (F7).

GUILD broadcasts:
| t | fields | semantics |
|---|---|---|
| N | i, x, g, c | new bet; author=sender; peers synthesize p={[sender]="Y"}, pe=0 (F22); REJECT if id already exists locally (F11) |
| J | i, s | sender joins side s ("Y"/"N"); applied only while local status==open |
| L | i | sender leaves; only while open |
| K | i, e, n, m | lock by author (sender==author validated); e=epoch (per-bet counter, starts 1), n=#participants, m=#chunks; clears any chunk buffer for i (F4); m==0 ⇒ replace with empty list immediately (F22); status applied via ApplyToggle(e, locked) — stale e < le never re-locks (U1/U2) |
| U | i, e | unlock by author (v1.0): reopen a locked bet via ApplyToggle(e, open); e = bumped shared epoch, no participant payload (the list a lock froze stays and live J/L flow again); terminal statuses immune (U1) |
| P | i, e, q, pp | chunk q/m, pp = array "Name=Y"; buffered iff e matches current buffer epoch; when all m arrived → REPLACE bet.p, set pe=e, clear incomplete (F4) |
| C | i | cancel by author |
| R | i, w, e | resolve by author; from any non-terminal status → resolved, win=w, re=e; plan+stats valid iff pe==e else mark incomplete, UI "payment plan syncing…" (F3); client sends K+P (fresh epoch) immediately before R |
| T | i, x, v | payment handshake (v0.9.1): x = payment index in the DETERMINISTIC plan order, v=1 payer claims paid (sender must equal payments[x].from), v=2 receiver confirms (sender must equal .to). Per-position monotonic max; stored as bet.ps={[idx]=1|2} with epoch stamp bet.psE (== re, wiped if stale) |
| H | v, k | HELLO: version, active-bet count. Sent after login gate (below) and via Sync button |
| A | p (target) | sync claim: "I will answer <target>" |
| D | p (target) | sync claim done: "I finished answering <target>" (F12) |
| Q | i | (whispered TO author, listed here for completeness) request fresh K+P; author re-broadcasts K+P, rate-limited 30 s per bet (F9) |

WHISPER sync (claimer → HELLO sender):
| t | fields | semantics |
|---|---|---|
| S | i, a, x, g, c, st, w, re, rt, rb, e, n, m, le | bet meta; `e` = the MIRROR's participant epoch, `re` = the author's resolve epoch (travel separately — an incomplete mirror must not hand out a false "complete" flag); `le` = the mirror's lock-toggle epoch, sent for open/locked bets only (terminal S stays within budget); followed by its P chunks (whisper). Merge: unknown id → insert (firstSeen=now); terminal statuses adopt by strictly-higher rank; the open/locked axis adopts the mirror status iff mirror le > local le (U3 — rank must not re-lock what the author unlocked); participants: a complete chunk set REPLACES only when e > local pe AND e >= local le; e == local pe or e < local le (snapshot older than the last unlock — it may miss joins made since) UNIONS without deleting (U4 — subsumes the old epoch-0 union rule; protects live joins on a reopened bet from stale and same-epoch mirrors). A union skips my own entry iff bet.my is set (U5) |

**Byte budget check** (F7, worst case, 12-char names, 100-cost text):
S = 8 (envelope) + 6 (t) + 26 (i=Author-nnn-999) + 17 (a) + ~123 (x) + 8 (g)
+ 10 (c offset) + 6 (st) + 6 (w) + 10 (rt) + 18 (rb) + 6 (e) + 6 (n) + 6 (m)
≈ 256 — still tight ⇒ S omits x beyond 80 cost? NO — instead S splits meta:
resolved bets send rt/rb, open bets don't (w/rt/rb absent). Open-bet S ≈ 216.
Resolved-bet S drops `c` (display-only, non-critical) ⇒ ≈ 246. Backstop: the
pre-send assert + text cap gives deterministic sizes; if assert would fail,
truncate x to fit (text is display-only in S; the authoritative text came with
N). P with 6 names ≈ 170. N ≈ 190. All ≤ 245.

**Text rule** (F8): input validation on SERIALIZATION COST, not chars:
`cost = #text + count(" ") + count("~") + count("^") ≤ 100`; live counter in
create bar shows remaining cost. Input strips `|` and control chars; render
of ANY remote text escapes `|` → `||` (F16b — non-negotiable).

**Determinism** (F17): every "alphabetical" sort uses an explicit byte-wise
comparator (string.byte loop), never bare `<` (strcoll is locale-dependent).

## Login sync

Gate (F19): after PLAYER_ENTERING_WORLD, wait for `IsInGuild()` AND first
GUILD_ROSTER_UPDATE (call GuildRoster() to trigger), then +10 s jitter → send
H. Retry H up to 2× (30 s apart) if no inbound guild addon traffic seen yet.

Peers on receiving H from X: if nothing to offer (no active bets, no recent
resolved) → stay silent. Else schedule reply at random(2..6) s. Seeing A{X}
DEFERS own reply to +20 s (not cancel, F12); seeing D{X} cancels it. On fire:
broadcast A{X}, whisper snapshot burst (S+P per bet) at BULK priority (F13),
broadcast D{X}. Per-target cooldown: answer the same X at most once / 10 min.

Snapshot selection (F14): all open/locked + resolved/cancelled ≤14 days,
sorted by (X is participant) DESC, then newest, cap 15.

X-side watchdog (F12): if an A{me} was seen but no S arrived within 15 s →
re-send H (max 2). If no A at all → nothing to sync (or nobody online);
manual Sync button remains.

Duplicate bursts are harmless — merge is idempotent.

**Echo watchdog** (F20): after each GUILD broadcast, arm 5 s timer; own echo
clears it. If it fires: once per session print "[SoTBookie] Your guild addon
messages aren't being delivered — ask an officer to check your rank's guild
chat permissions." (This IS the rank-permission detector.)

**Version hint**: H carries numeric version; seeing a newer one → once per
session print "[SoTBookie] A newer version exists — grab it from the guild."

## Pot math (deterministic, F17/F18/F22)

Winners = p[x]==win side, losers = other side, both byte-sorted. Resolve is
UI-blocked while either camp is empty. pot = gold × #losers.
base = floor(pot/#winners); first (pot mod #winners) winners get base+1.
Assignment: iterate losers in order, each owes `gold`, filling winners'
remaining quotas in order (a loser's payment may split). Zero-gold rows are
suppressed from the displayed plan but the winner still counts a win (F18).
Settled keys = "From>To" per plan row; orphaned keys (plan changed after a
participant correction) are kept harmlessly (F18; a visual "plan updated"
marker is deferred to v1.1).

## Stats (F6)

Fold on demand: start from `db.global.aggregate`, add every resolved bet with
pe==re (complete). Per player: net gold, wins, losses, biggest single win.
Leaderboard ranks by net gold (1g-bet stat-gaming is pointless, A4.6).
Incomplete resolved bets show a syncing marker and contribute nothing yet.

## Revisions 2026-08-18 (post smoke test, user decisions)

- **Language**: everything Czech WITHOUT diacritics beyond Latin-1 — the stock
  3.3.5 font has no č/ř/š/ž/ě/ů glyphs (window AND chat would show holes).
  For style consistency ALL diacritics are stripped ("Otevrena", "pred 5 min").
- **Payments = guild-shared handshake** (replaces private per-char checkboxes,
  db.char.settled dropped): 0 unpaid → 1 payer claims ("Zaplaceno") → 2
  receiver confirms ("Prislo"). Message T above; S mirrors carry `y` = digit
  string ("0120") merged per-position max (parked in comm state until the bet
  is computable). Stats/prune/login-notice now key off state<2.
- **Tabs: Aktivni | Historie | Dluhy | Zebricek | Nastaveni.** Historie is a
  read-only paper trail (Again button removed). Dluhy = ledger aggregated per
  counterparty+direction with bulk claim/confirm buttons. Zebricek = pure
  leaderboard. Nastaveni = options + manual sync button with explanation
  (footer Sync button removed).
- **Buttons auto-size** to their label (+22 px) and author rows wrap buttons
  to a second line when needed.
- New-bet sound switched to "AuctionWindowOpen" (checkbox click sound was
  inaudible); enabling the option plays it once as a preview.

## UI (single window `SoTBookieFrame`, ~480×540, ESC-closable, movable)

- Never auto-opens, no modal popups from network events, no sounds by default;
  optional out-of-combat-only new-bet sound (profile, default OFF). New bet /
  resolve also print ONE local chat line (only addon users see their own).
- **Tabs: Active | History | Stats.**
- Active: create bar (statement box with live cost counter, gold box, Create;
  Enter submits) + scrollable bet rows: statement, "300g · by Wydlica · 5m ago
  · OPEN/LOCKED", camp lines "YES (2): …" / "NO (3): …", one-click YES/NO/leave
  buttons (dimmed when locked), author-only Lock/Cancel/Resolve YES/NO,
  Announce. Resolve → confirm dialog listing the full payment plan (F: A3.6)
  with an "announce result" checkbox.
- History: resolved/cancelled/expired rows: statement, result + pot, resolver
  + when (paper trail), payment plan with settled checkboxes (mine highlighted),
  "Again" button (refills create bar). Login notice once synced: "[SoTBookie] N
  resolved bets involve you with unsettled payments — /bet".
- Stats: byte-sorted-by-net leaderboard: name, net (green/red), W/L, best win.
- Sync button (footer) — re-sends H.
- Announce (manual only, AUTHOR only, create + resolve only): one line to RAID if in raid,
  else PARTY if grouped, else GUILD. Rotating playful templates, winners/pot
  only, never loser names, play-money vocabulary (no "bet/wager/odds/gamble"
  in public strings — A2.18). Examples in Core ANNOUNCE_* tables.

## Deliberate non-goals (v1)

Hard gold enforcement; join toast popup (V2); quick-bet templates (V2);
cross-bet debt netting (V2); head-to-head, hall of fame, titles, season
resets, debt aging, losing-streak nudge, designated resolver (all V2 — see
USER-STORIES.md); any automatic chat output.

## File layout

SoTBookie.toc (Interface 30300, SavedVariables SoTBookieDB) → embeds.xml →
Core.lua (init, DB, store ops, pot math, stats, text rules, helpers) →
Comm.lua (protocol above) → UI.lua (window) → Minimap.lua (LDB + LibDBIcon).
Libs: Ace3 r960 subset + LibDataBroker + LibDBIcon (committed).
