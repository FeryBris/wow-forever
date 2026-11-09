# Raidify Loot — Changelog

## 0.2.5

**Not needed on World of Warcraft: Forever any more.** Raidify on Forever now has loot council
built in, so this addon no longer loads there and you can remove it from that client. Classic
Era, TBC and Mists are unchanged.

## 0.2.4

**Now on Wago Addons as well as CurseForge.** Same addon and the same releases; install it from
whichever you already use. Nothing else changes in this version.

## 0.2.3

**Runs on World of Warcraft: Forever.** Install it as usual alongside Raidify; the right version
is picked for you. Forever is built on the modern client, where the calls this addon uses to read
an item's name, icon and quality had moved — every item in the loot window, the candidate cards,
the owed list and the session record now resolves there.

Master loot works on Forever too. It was briefly thought not to exist on that version; it does,
and the addon finds it.

Nothing changes on Classic Era, TBC or Mists.

## 0.2.0

The first release anyone outside the project can install. Thirty-five changes since
0.1.0; the ones that matter to an officer running a night:

**The session survives things.** A disconnect, a `/reload` or a crash mid-raid no longer
costs the officer their wishlists or their queue. A session has three distinct states, and
starting one only resumes the interrupted one rather than wiping it.

**The night is no longer only on one person's client.** The session syncs to the raid, so
the card can be screenshared and the officers see the same thing.

**The card ranks people.** It shows who is actually in the raid, with rank, tier, priority
and attendance, sorted — and it draws every candidate rather than the first twelve. Guests
are tagged as guests, and the tag survives the drops it was built for. Anyone who already
won tonight is marked. Offspec is a tick box on the candidate card.

**Trading.** The owed list understands the two-hour trade window, auto-trade is a toggle on
the Loot page, and the addon can hand out what the master looter is carrying.

**It tells you what it is doing.** `/rf loot` answers "am I recording right now?", the card
says whether it will record, and the raid is told when its lists are locked. Awards are
announced.

**Test mode fills in wishlists, not just people** — so the card sorts, chips appear, and the
ordering can be judged before a real raid rather than during one.

Fixes worth naming: the card no longer mistakes one item for another; three real bugs in the
trade logic, found by reading Gargul rather than guessing; the Loot page stays live while it
is open; and a standalone session can actually draw a card.

## 0.1.0

First separate release. Loot council features moved out of the core Raidify addon
into this optional companion addon.

- **Requires the Raidify addon.** Install both; this one does nothing on its own and
  will say so rather than erroring if Raidify is missing or out of date.
- **`/rf loot`** and the rest of the loot commands now live here. A Raidify install
  without this addon answers `/rf loot` with an install hint.
- **Your loot session survives a `/reload` or a crash.** Previously the queue and every
  award recorded during a session lived only in memory, so a disconnect mid-raid lost
  the lot. Sessions are now saved as they go and recovered at login — paused rather
  than resumed, so nothing restarts watching loot behind your back.
- **Your own saved variables.** Loot data lives in `RaidifyLootDB`, separate from
  Raidify's. Your loot quality threshold and award-announce setting carry over from
  the old core version automatically.
- Loot errors can no longer break the core Raidify addon.
