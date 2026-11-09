# Raw user stories — angle 3: edge cases & lifecycle failures

Generated 2026-08-13 (night design run), Sonnet subagent. Consolidation lives in USER-STORIES.md.

Format: scenario / expectation / what current design does / verdict.

1. **Author DCs/logs off before resolving; bet dangles forever.** Expect stale-bet signal or resolution path. No timeout in design. **Needs attention.**
2. **Joiner sends JOIN then instantly DCs** — message may not have flushed; no ack; membership may diverge until next sync. **Needs attention.**
3. **/reload mid-bet.** State in SavedVariables; identical after reload. OK.
4. **Login after a bet was created AND resolved while offline.** Snapshot must include recent resolved bets or history/stats diverge permanently. **Needs attention.**
5. **Two simultaneous creates.** OK if IDs are author-scoped (name+counter), no shared counter. Confirm ID scheme.
6. **Author misclicks RESOLVE on wrong side.** No undo described; payment plan + stats lock in everywhere. **Needs attention** (confirm dialog showing plan; possibly re-resolve).
7. **CANCEL after LOCK.** Merge precedence implies it's a valid transition; confirm it's an intended author action in UI. OK if explicit.
8. **Everyone in same camp, author resolves anyway.** Zero losers → empty plan, free "win". Verify empty-loser path; better to block resolve of one-sided bets (suggest cancel). **Needs attention.**
9. **Stake 100000g or 1g.** No sanity range in design. **Needs attention** (min/max + confirm on outlier).
10. **Czech diacritics near byte limit.** Char-count limit undercounts UTF-8 bytes → mid-multibyte truncation. **Needs attention** (byte-aware limit at input).
11. **Same statement bet twice.** IDs distinct; UI must disambiguate identically-worded open bets (author + time visible). **Needs attention** (UI clarity).
12. **Author leaves guild mid-bet.** Their RESOLVE can never reach the guild (GUILD-channel only). Bet permanently stuck. **Needs attention.**
13. **Participant leaves guild before settling.** Degrades gracefully — manual settlement works regardless. OK.
14. **Author resolves from an alt.** Authority = character name; alt fails validation silently. **Needs attention** (explicit "one character = one identity" rule surfaced in UI).
15. **Settled state after prune.** Pruned with the bet; unsettled debts silently lost. **Needs attention** (exempt unsettled bets from auto-prune or warn).
16. **Stats double-count on duplicate RESOLVE (broadcast + sync snapshot).** Must be state-transition based / recomputed from final state, never incremented per message. **Needs attention** (explicit rule).
17. **Clock skew between clients.** Status-precedence merge is clock-independent (good); avoid raw-timestamp tie-breaking anywhere. OK with care.
18. **Ignore-list silently drops messages.** No client fix; document + rely on periodic/HELLO reconciliation. **Needs attention** (document; sync corrects).
19. **Rank without "guild chat listen"** — addon looks broken (receives nothing). **Needs attention** (detect: "no guild addon traffic seen" hint in UI).
20. **Version mismatch: old client gets unknown message type.** Parsing must be defensive: ignore unknown types/fields; version tag in HELLO. **Needs attention.**
21. **Self-echo of own GUILD messages.** Known trap; dedup by sender==me or idempotent apply. OK if handled + tested.
22. **Pot doesn't divide evenly.** Needs exact integer arithmetic + remainder-distribution rule, identical on all clients. **Needs attention** (spec'd rounding).
23. **Join/switch burst right before LOCK; race between LOCK and last-second switch.** Define: receiver applies JOIN only while local status is open; late JOINs dropped; sync reconciles to author's view. **Needs attention** (author snapshot at lock is authoritative).
24. **Out-of-order control messages.** Status precedence converges. OK.
25. **Non-participant sees all bets in history/stats?** Clarify scope: history = all guild bets (it's a shared board), stats = participants only. **Needs attention** (decide + display clearly).
26. **LEAVE lost in transit** — peer keeps player in camp; divergent money math. Same unacked-delivery family as #2/#18/#19; author lock-snapshot reconciliation fixes. **Needs attention.**
27. **Player misses resolve entirely (offline), syncs later.** Needs proactive "you have N unsettled resolved bets" notice on login, not just a UI they might not open. **Needs attention.**
28. **Bet text contains `|` (WoW escape codes) or delimiter chars.** Sanitize on input and render (escape `|` as `||`). **Needs attention.**

## Top 8 design gaps ranked by likelihood × pain

1. **Stuck bets from author DC/guild-leave (#1, #12)** — fix: auto-expire to cancelled after N days + anyone-can-hide locally.
2. **Silent membership divergence from lost messages (#2, #18, #19, #26)** — fix: author's LOCK/RESOLVE carries the full participant snapshot; peers adopt it (authoritative reconciliation).
3. **Stats double-counting (#16)** — fix: stats applied only on state transition to resolved, guarded by per-bet "statted" flag / recomputed from state.
4. **No confirm on RESOLVE (#6)** — fix: confirmation dialog showing the computed payment plan before sending.
5. **Multibyte truncation (#10)** — fix: byte-length input validation.
6. **Late joiners missing resolved bets (#4, #27)** — fix: snapshots include recent resolved bets + unsettled notice.
7. **Stake sanity + rounding spec (#9, #22)** — fix: min 1g, max confirm; integer gold, remainder to alphabetically-first winners.
8. **Alt/main authority mismatch (#14)** — fix: document rule; v2 could allow designated resolver.
