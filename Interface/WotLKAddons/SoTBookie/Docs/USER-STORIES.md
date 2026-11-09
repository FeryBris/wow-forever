# SoTBookie — user-story coverage matrix

Consolidated 2026-08-13 from 4 subagent ideation passes (~90 stories; raw lists in
`stories-raw-*.md`). Story references: A1.3 = angle 1 (raid night), story 3.
Angles: A1 raid night · A2 social/non-users · A3 edge cases · A4 long-term fun.

Verdicts: **COVERED** (agreed design handles it) · **V1+** (refinement folded into
v1 tonight — within agreed scope, flagged for morning review) · **V2** (proposal,
needs user approval) · **DOC** (handled by documentation/social rule, not code) ·
**REJECTED** (deliberately not doing).

## 1. Creating & joining bets (A1.1-2, A1.5, A1.14-17, A4.5, A4.10, A4.16)

| Story | Verdict | Resolution |
|---|---|---|
| Create in <15 s between pulls (A1.1) | **COVERED** | Create bar = one text box + one gold box + Create button, Enter submits. |
| Join with minimal clicks (A1.2) | **COVERED** | One click on YES/NO directly in the bet list row. |
| Watch without committing (A1.5) | **COVERED** | Active list always shows live camp counts + names; joining never required. |
| Bet text readable at a glance (A1.14) | **V1+** | Byte-aware limit (~120 B) keeps texts short; full text always visible in the row (wrapped), no tooltip needed. |
| Switch/leave camp in one click (A1.15) | **COVERED** | Clicking the other camp switches; clicking own camp again leaves. Instant broadcast. |
| Join after lock fails silently (A1.16) | **V1+** | Locked bets render dimmed buttons + LOCKED tag; JOIN messages arriving after local lock are dropped; author snapshot at lock is authoritative (see §4). |
| Self-explanatory for first-time user (A1.17) | **COVERED** | Row shows statement, stake, author, camps, YES/NO buttons — no manual needed. |
| Quick-bet templates (A4.5, A4.14) | **V2** | Template/quick-bet system — proposal for user. |
| Re-run identical bet in one click (A1.23, A4.18) | **V1+** | "Again" button on resolved/cancelled bets re-fills the create bar (one click + confirm). |
| Concurrent bets unambiguous (A1.7, A4.16) | **V1+** | Single compact list (no per-bet popups); each row shows author + age; identical texts distinguishable (A3.11). |
| Silly ceremony-free bets (A4.10) | **COVERED** | Same 2-field create path regardless of stake/subject. |

## 2. Combat & raid-night safety (A1.3-4, A1.6, A1.8-13, A1.18)

| Story | Verdict | Resolution |
|---|---|---|
| No taint / never blocks secure frames (A1.11) | **COVERED** | Plain non-secure frame, no keyboard capture except its edit boxes, ESC closes; never auto-opens. Reviewer checklist item. |
| Misclicks mid-fight (A1.4) | **V1+** | Window never auto-opens; no modal dialogs from network events, ever. (Auto-hide in combat = V2 option.) |
| Auto-lock at pull (A1.3) | **V1+** | Opt-in setting (default OFF): author's client locks their own open bets on entering combat. Manual Lock stays primary. Flag for morning. |
| Missed the bet while tabbed out (A1.6) | **V1+** | Local chat line on new bet ("[SoTBookie] Wydlica calls: ... 300g — /bet") + minimap icon shows open-bet count in tooltip. Popup toast = **V2**. |
| One-click resolve after wipe (A1.8) | **COVERED/V1+** | Resolve = two clicks (YES won / NO won + confirm dialog showing payment plan — the confirm is deliberate, see A3.6). |
| Results don't fight the loot window (A1.9) | **COVERED** | Resolve produces a local chat line + data in window; no popups. |
| Multi-bet settle in one view (A1.10) | **V2** | Cross-bet per-person netting ("you owe Bob 450g total") — proposal. V1 shows per-bet plans. |
| Sounds (A1.12-13) | **V1+** | Default fully silent. One optional subtle sound on new bet, only out of combat, default OFF. |
| RL quiet mode (A1.18) | **COVERED** | Addon is silent by default; nothing to quiet. |
| No gold enforcement (A1.19) | **COVERED** | Deliberate design principle — trust-based, addon never pretends to verify gold. |

## 3. Social & non-addon guildies (A2.*)

| Story | Verdict | Resolution |
|---|---|---|
| Announce is one clean line, no addon syntax (A2.1, A2.6, A1.22) | **V1+** | Rotating playful templates, winners-centered, no slash commands, no loser names, play-money wording ("calling it", "tab", "pot" — never "gamble/wager/odds"). |
| Announce frequency fatigue (A2.11, A2.17, A2.19) | **V1+** | Announce exists only on create + resolve, manual button only, one line each. No lock/cancel announces. |
| Loser-shaming in public (A2.7, A2.14, A2.22) | **V1+** | Public lines name the winning side + pot only; per-loser breakdown stays inside the addon. |
| Gambling optics (A2.3, A2.18) | **V1+** | Public string vocabulary audit (see DESIGN.md Announce section). |
| Install funnel dead end (A2.5, A2.12, A2.21) | **DOC** | README written for guild distribution; recommend pinned ZIP in guild Discord before announcing liberally. Morning point for the user. |
| Bets about non-consenting guildies (A2.16) | **DOC** | Highest drama vector. Social rule in README ("betting about a guildie? invite them in"). No code enforcement. Morning discussion point. |
| Debt lingering / forgiveness (A2.13, A2.15, A4.12) | **V2** | Debt aging view / "forgive" gesture — proposal. V1: unsettled bets never auto-prune (A3.15). |
| Stats as gossip fodder (A2.10, A2.22) | **COVERED** | Stats live only in the addon window; addon never broadcasts stats to chat. Rest is guild culture. |
| Bank-alt settlement (A2.9) | **COVERED** | Settlement is manual trade; addon doesn't care which character pays. |
| Guild-identity voice (A2.8, A2.20) | **V1+** | Consistent "SoTBookie:" prefix + rotating templates. |

## 4. Lifecycle & sync correctness (A3.*)

| Story | Verdict | Resolution |
|---|---|---|
| /reload survives (A3.3) | **COVERED** | All state in SavedVariables. |
| Author DC / leaves guild → stuck bet (A3.1, A3.12) | **V1+** | Deterministic local auto-expire: open/locked bets older than 72 h show as EXPIRED (treated as cancelled). Converges without messages. |
| Lost JOIN/LEAVE → divergent money math (A3.2, A3.23, A3.26) | **V1+** | **Authoritative snapshot rule**: LOCK (and resolve, which implies lock) broadcasts the author's full participant list in chunks; peers replace theirs. Money math always computed from author's snapshot. |
| Late joiner misses resolved bets (A3.4, A3.27) | **V1+** | Sync snapshots include resolved/cancelled bets ≤14 days (cap 15). Login notice: "N resolved bets involve you with unsettled payments." |
| Simultaneous creates collide (A3.5) | **COVERED** | Bet id = `AuthorName-counter` (per-character persistent counter) — author-scoped, collision-free. |
| Misclick resolve (A3.6) | **V1+** | Confirm dialog shows full computed payment plan before broadcasting. No undo in v1 (**V2**: author re-resolve within 5 min). |
| Cancel after lock (A3.7) | **V1+** | Explicitly allowed (author action) — "bet fell through" path. |
| One-sided bet resolve (A3.8) | **V1+** | Resolve blocked while either camp is empty; UI suggests Cancel. |
| Stake sanity (A3.9) | **V1+** | Integer gold ≥ 1; confirm dialog above 1000 g. |
| Diacritics vs byte limit (A3.10) | **V1+** | UTF-8 byte-length validation at input (limit 120 B), live counter. |
| Same text twice (A3.11) | **V1+** | Rows show author + age; ids independent of text. |
| Participant leaves guild (A3.13) | **COVERED** | Settlement is manual; history keeps the record. |
| Alt resolves author's bet (A3.14) | **DOC** | Rule: one character = one identity; stated in README + UI tooltip. **V2**: designated resolver. |
| Unsettled bets pruned (A3.15) | **V1+** | Prune (>50 resolved) skips bets where I participate with unchecked payments. |
| Stats double-count (A3.16) | **V1+** | Stats applied exactly once per bet on transition to resolved, guarded by per-bet `statted` flag; never per-message increments. |
| Clock skew (A3.17) | **COVERED** | Merge = status precedence, clock-independent; timestamps display-only + expiry (72 h tolerance dwarfs skew). |
| Ignore-list / rank silently drops messages (A3.18-19) | **V1+/DOC** | Documented in README; manual "Sync" button re-runs HELLO; snapshots self-heal. Rank-detection heuristic = **V2**. |
| Old client gets unknown message (A3.20) | **V1+** | Defensive parsing: unknown `t` ignored; HELLO carries version; newer-version hint in UI. |
| Self-echo (A3.21) | **COVERED** | Handler ignores `sender == me` (echo = delivery confirmation only). |
| Pot rounding (A3.22) | **V1+** | Spec: integer gold; winners sorted alphabetically; base = floor(pot/n), first (pot mod n) winners get +1; greedy loser→winner assignment in sorted order. Deterministic everywhere. |
| Out-of-order control messages (A3.24) | **COVERED** | Status precedence open < locked < cancelled/resolved. |
| History scope (A3.25) | **V1+** | History = all guild bets (shared board); stats count participants only. |
| `|` escape codes in text (A3.28) | **V1+** | Strip `|` on input; escape on render. |

## 5. Long-term fun & retention (A4.*)

| Story | Verdict | Resolution |
|---|---|---|
| Resolving cheap for the SoTBookie (A4.1, A4.18) | **V1+** | Resolve visible on every active row (author only); "Again" re-run button. |
| Stats beyond "biggest loser" (A4.2, A4.21) | **PARTIAL/V2** | V1: net gold, W/L count, biggest single win. Titles/badges/hall of fame = **V2**. |
| Stake norms for newcomers (A4.3, A4.22) | **V2** | Suggested stake / stake trends — proposal. |
| One-button flavorful result announce (A4.4) | **COVERED** | Resolve confirm dialog has "announce" checkbox. |
| 1g stat-gaming (A4.6) | **COVERED** | Leaderboard ranks by net gold, not win % — 1g bets can't game it meaningfully. |
| Losing-streak resentment (A4.7) | **V2** | "You've lost X this week" soft nudge — proposal. |
| Head-to-head records (A4.8) | **V2** | Proposal. |
| Long-running bets (A4.9) | **COVERED** | Manual lock; 72 h expiry ≫ one raid night. Auto-lock is opt-in per author. |
| History as digest (A4.11) | **PARTIAL** | V1 history shows text, result, pot, resolver, age. "Tonight" filter = **V2** (A1.21). |
| Paper trail on resolve (A4.15) | **V1+** | History row shows who resolved and when. |
| Leaderboard reset scope (A4.20) | **V2** | Season/tier resets — proposal (v1 = all-time; reset needs a design decision). |
| No participation shaming (A4.19) | **COVERED** | No "bets placed" ranking; stats only show what you did, not what you didn't. |

## Summary for morning review

- **Folded into v1 (V1+):** resolve-confirm with payment plan, authoritative
  participant snapshot at lock/resolve, sync includes recent resolved bets +
  unsettled-notice, 72 h auto-expiry, byte-aware text limit + `|` sanitization,
  stats idempotency flag, deterministic pot rounding spec, stake sanity checks,
  one-sided-resolve block, cancel-after-lock, "Again" button, local new-bet
  chat line, prune protection for unsettled bets, announce template pack
  (winners-only, play-money voice), defensive parsing + version hint,
  manual Sync button, opt-in author auto-lock on combat, opt-in sound.
- **V2 proposals (need user approval):** join toast popup, quick-bet templates,
  cross-bet per-person debt netting, debt aging/forgiveness, head-to-head
  records, hall of fame/titles, season resets, "tonight" history filter,
  losing-streak nudge, designated resolver for alts, rank-permission detector.
- **Documentation/social (README):** install funnel via pinned guild Discord ZIP,
  "bet about a guildie → invite them in" etiquette, one-character-one-identity,
  ignore-list/rank silent-drop traps.
