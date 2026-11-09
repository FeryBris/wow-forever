# Raw user stories — angle 1: the raid night itself

Generated 2026-08-13 (night design run), Sonnet subagent. Consolidation lives in USER-STORIES.md.

1. **Bet author (tank, about to pull)** / has ~15 seconds before pulling, wants to fire off "we wipe" as a joke / types statement + stake, hits Create, addon posts it to guild channel silently and the window can be dismissed with one click or Enter / *breaks fun if creating a bet requires more than 2 fields + 1 click, or if the window doesn't close itself and blocks the screen when the pull starts.*

2. **Camp joiner (DPS, hands on rotation)** / sees a bet popup in a corner icon/toast during the inter-pull lull / wants to join YES or NO with a single click on a small always-on-top toast, no need to open a full window / *annoying if joining requires opening a config-style AceGUI panel — that's a multi-second detour they won't take mid-raid.*

3. **Raid leader** / calls "pulling in 3, 2, 1" while a bet is still open / expects the addon to auto-lock the bet the instant combat starts (or on a RL-configurable countdown), with zero manual step needed from the author / *breaks fun if bets stay joinable mid-pull and cause "wait I wanted in" arguments after combat starts, or if auto-lock fires falsely during trash re-pulls.*

4. **Healer, mid-fight** / accidentally has the addon window focused when spam-clicking to top off the tank / expects the bet window to never intercept clicks or keybinds while in combat, and to auto-minimize to icon-only during combat / *breaks fun (and possibly a wipe) if a misclick on the bet UI eats a heal, or if the frame can't be clicked through.*

5. **Undecided lurker** / wants to watch a bet unfold without picking a side yet, maybe waiting to see how confident others look / expects to see live camp counts (e.g. "YES 4 · NO 2") without being forced to commit / *annoying if the only way to "peek" at a bet is to open a heavy tabbed window that also shows unrelated history/stats.*

6. **Person who tabbed out (browser during a boss explanation)** / misses a bet's creation and lock entirely / expects the minimap icon to flash/pulse for "bet open, closing soon" so they can glance and decide in 2 seconds, and expects late views of a locked bet to clearly show "LOCKED — can't join" instead of dead clickable buttons / *breaks fun if there's no ambient signal at all — this player just never gets to participate, ever, and stops caring about the addon.*

7. **Person managing 3 simultaneous bets** (e.g. "wipe or not," "who dies first," "loot roll over/under") / needs to track stakes across all three without losing count / expects a compact list (not three separate popups) showing text, their camp, stake, and status per bet / *annoying if each bet is a separate floating window — screen clutter during a boss fight is a hard no.*

8. **Bet author, resolving right after a wipe** / raid is regrouping, everyone's running back, 10-second window before people start typing "again" / expects one-click YES/NO resolve immediately visible from the toast/icon, with the payment plan auto-generated and posted instantly / *breaks fun if resolving requires navigating into a submenu or if the addon can't tell the difference between "wipe = NO" and needs the author to hunt for the right bet in a list.*

9. **Camp joiner, reading results during loot** / boss just died, loot window is open, addon should not compete for attention / expects the payout summary to sit quietly in the bet window/history (or a small chat line), not a popup that steals focus over the loot roll frame / *annoying/breaks fun if a modal payment-plan window pops over the loot UI and delays someone's need/greed click.*

10. **Person with 3 concurrent bets, all resolve at once** / after a big pull with several side-bets ("first death," "wipe," "under 2 min") / expects one consolidated "settle up" view listing all owed/owing amounts summed per person, not three separate trade prompts / *breaks fun if they have to whisper-trade three separate times with the same person for three small amounts instead of one net number.*

11. **Window open during combat** / player has the SoTBookie frame pinned open out of habit / expects it to never taint or block secure action buttons (action bars, focus/target macros) even while visible / *breaks fun catastrophically if the addon causes action-bar taint mid-fight — this is the single fastest way to get uninstalled.*

12. **Sound/notification preference — new bet created** / a bet appears while the raid is between trash packs, chatting / expects an optional, subtle sound only when NOT in combat, off by default or easily toggled / *annoying if a sound plays during a boss fight (masking voice comms or important raid warnings) or during a serious wipe-recovery moment.*

13. **Sound/notification — bet about to lock** / author is about to pull and forgot people were still deciding / expects an optional short "final call" cue (visual pulse, maybe a quiet tick) a few seconds before auto-lock / *annoying if it's a loud sound that overlaps DBM/BigWigs alerts — must never compete with raid-critical audio.*

14. **Bet text readability at a glance** / player glances at a toast for under a second while dodging a fire patch / expects short bet text (enforced or truncated, e.g. 40 chars) rendered in a legible font/size with camp choice visible without hovering / *breaks the fun if long joke statements get cut off mid-word or require a tooltip hover to read while moving.*

15. **Person who wants to switch or leave a camp** / joined NO impulsively, boss mechanics reveal it's going fine, wants to switch before lock / expects a single click to flip camps or leave entirely, reflected instantly for everyone / *annoying if switching requires "un-join then re-join" as two separate actions, or if there's no visible confirmation the switch registered before lock hits.*

16. **Person who tries to join after lock** / clicks YES a half-second after the pull starts / expects a clear, immediate "locked" state (dimmed buttons, no response) rather than silent failure / *breaks trust if the client shows the click "succeeded" locally but the author's side never counted it — desync between viewers is the fastest way to spark an argument.*

17. **New guildie, first time seeing a bet** / has the addon but has never used it, sees a toast mid-raid and doesn't know what it is / expects the toast itself to be self-explanatory (statement, YES/NO buttons, stake, who made it) without needing to read a manual / *annoying if onboarding requires opening docs or a help tab during raid time — if it's not obvious in 3 seconds, they'll ignore it forever.*

18. **Raid leader who wants zero distraction from the addon entirely** / is trying to run a tight progression night / expects an easy "quiet mode" respected by the addon (no sounds, only silent minimap-icon changes) / *breaks fun/trust if there's no way to dial down noise short of individuals disabling the addon — RL annoyance kills adoption guild-wide.*

19. **Person low on available gold** / wants to join a 500g bet but only realistically wants to risk 50g / expects the addon to simply reflect the stake the author set (trust-based, no in-addon gold check) / *annoying if the addon tries to enforce/verify gold ownership (impossible in 3.3.5 anyway) — false confidence there would be worse than no check at all.*

20. **Person AFK/disconnected when a bet resolves** / DCs mid-fight, bet resolves while they're reconnecting / expects the bet and its payout to still be waiting for them in history/pending-settlements when they log back in, not lost or auto-voided / *breaks fun if a DC silently drops them from a camp they were genuinely part of, especially if they'd have won.*

21. **Person reading History/Stats post-raid** / wants to see tonight's bets, running net gold, bragging rights / expects a fast tab with the night's bets grouped / *annoying if there's no "tonight"/"this raid" filter and they scroll through 50 entries.*

22. **Person announcing a juicy bet to hype the raid** / wants the chat audience to see one clean line / *breaks fun if Announce dumps a wall of text (camp lists, stakes, instructions) into raid chat.*

23. **Bet author who wants to reuse a common bet** / runs the same "wipe or not" bet every pull on a hard boss / expects a fast-repeat path (recreate last bet with one click) / *annoying if every attempt requires re-typing — discouraging use exactly on wipe-fest progression nights.*

## Top 5 design risks/opportunities from this angle

1. **Combat-safety is existential, not cosmetic.** Any taint, click-block, or focus-stealing during a fight gets the addon uninstalled within one raid. Hard constraint, tested explicitly.
2. **The interaction cost of joining must be near-zero.** More than one click from an ambient toast and the between-pull window closes before anyone acts.
3. **Auto-lock tied to combat start is the make-or-break mechanic.** Manual-only locking produces "wait I wanted in!" disputes; decides whether the system feels fair.
4. **Notification restraint determines whether the RL/guild tolerates the addon.** Never compete with DBM/voice; default silent/visual-only, sound as explicit opt-in.
5. **Fast re-creation and consolidated settlement are the retention hooks.** Repeat-betting and multi-bet per-person net settlement must be frictionless.
