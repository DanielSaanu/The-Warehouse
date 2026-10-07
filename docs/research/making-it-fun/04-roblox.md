# 04 · Roblox: retention, social play, phones

Hub: [README](README.md). Sources: [07-sources](07-sources.md).
Tags: **[Roblox primary]** = Roblox filings or Creator Hub docs. **[3rd-party measured]** = an analytics firm with a
stated sample. **[unsourced]** = a blog figure with no traceable primary. **[opinion]** = journalist, creator, or this
report's inference.

## Takeaway

Roblox is a ~123M-DAU platform whose audience is now majority 13+, with the fastest growth in 18–34s. Roblox
publishes no retention benchmark and no current mobile share, but its own guidance is blunt: fun inside five minutes,
no long tutorials, short/mid/long goals, and trading, guilds and timed events for the month-one return. Its
recommendation engine ranks on a <60 s bounce window and on days friends played together. Third-party medians say
half of all sessions end before minute seven and that longer first sessions go with higher day-one return. The 2025
hits share a loop you can read in a minute, progress that accrues while you are away, collection plus trading, and
server-wide timed events. There is no proven 2D top-down template on Roblox to copy; the retention mechanics are
format-independent and are the safer thing to borrow.

## The numbers

| Metric | Value | Tag, source |
|---|---|---|
| DAU, Q2 2026 | 123M; Hours 29B; top-10 games ~20% of Hours (was ~30%); long tail Hours +25% YoY | Roblox primary ([Q2 2026 letter](https://www.sec.gov/Archives/edgar/data/0001315098/000162828026051059/ex991-robloxq22026earnin.htm)) |
| Age mix, Q2 2026 | 35% under 13, 38% 13–17, 27% over 18; US 18–34 DAU +42% YoY | Roblox primary (same) |
| Hours per DAU per day | 2.7 (2025); users try >24 experiences a month | Roblox primary ([FY2025 10-K](https://www.sec.gov/Archives/edgar/data/1315098/000131509826000024/rblx-20251231.htm)) |
| Session length | P25 2.4 min, P50 6.6, P75 14.5, P90 26.4, P95 37.1 | 3rd-party measured ([GameAnalytics 2025 Roblox](https://www.gameanalytics.com/cn/reports/2025-roblox-report)) |
| Sessions per day | median 2.0; P90 6.0; P95 8.0 (+33% YoY) | 3rd-party measured (same) |
| D1 by average session band | 0–3 min 4.3%; 7–12 min 7.9%; 13–18 min 10.2%; 19–24 min 11.5%; 25+ 10.8% | 3rd-party measured (same; sample skews to small games) |
| Bounce windows ranked on | <60 s and 61–180 s; also co-play days, play days D1/D2–7/D8–28 | Roblox primary ([Creator Hub: Discovery](https://create.roblox.com/docs/discovery)) |
| Mobile share | "~72% of hours" repeated by aggregators, untraceable; historical Roblox figure "80% of users" | unsourced / dated ([Exploding Topics](https://explodingtopics.com/blog/roblox-stats), [PocketGamer.biz](https://www.pocketgamer.biz/80-of-roblox-users-are-on-mobile-contributing-46-of-robux-revenue)) |
| Mobile sessions | iOS ~14 min, Android ~11 | unsourced aggregators ([Udonis](https://blog.udonis.co/mobile-marketing/mobile-games/roblox-player-count)) |
| "Good" D1 | 30–40% folk benchmark; genre-dependent | unsourced ([RoWatcher](https://rowatcher.com/news/retention-benchmarks-by-roblox-genre-what-good-actually-looks-like)) |
| "45% leave in 30 s" | no primary source found | unsourced ([obby.fun](https://www.obby.fun/blog/roblox-analytics-guide)) |

The D1 medians are low because the sample is dominated by small games; read the **shape** (longer sessions ↔ higher
return), not the absolute numbers. Roblox's own retention doc defines D1/D7/D30 and gives no percentages ([Creator Hub: Retention](https://create.roblox.com/docs/en-us/production/analytics/retention)).

## What Roblox tells creators [Roblox primary]

- "Ensure users have fun within the first five minutes"; avoid lengthy tutorials; "short, unobtrusive pop-up
  instructions"; starter items; "reduce unnecessary barriers to social interaction"; "clear short, mid, and
  long-term goals" that do not gate the fun ([Creator Hub: Engagement](https://create.roblox.com/docs/en-us/production/analytics/engagement)).
- Onboarding: teach controls and the core loop ("what they are expected to do and why"), get to the fun quickly
  because players "decide their interest in a game within minutes", leave them wanting more; A/B test "a shorter
  dialogue sequence versus a guided arrow" ([Creator Hub: Onboarding](https://create.roblox.com/docs/en-us/production/game-design/onboarding)).
- By horizon: D1 → core loop, brief tooltips, device performance; D7 → progression with short and long goals, content
  variety; D30 → "smaller updates every 2–4 weeks" and "social mechanics like trading, guilds, PvP, and leaderboards"
  ([Creator Hub: Retention](https://create.roblox.com/docs/en-us/production/analytics/retention)).
- Core loops have three layers: minute-to-minute interaction, the most-repeated defining action, a progression engine;
  "Without a progression system, a game becomes repetitive, boring, and shallow" ([Creator Hub: Core loops](https://create.roblox.com/docs/en-us/production/game-design/core-loops)).
- RDC 2025's Creator Rewards pay for sustained time and return visits [3rd-party report of a Roblox announcement]
  ([allthings.how](https://allthings.how/roblox-rdc-2025-10-creator-tools-and-updates-that-matter/)).

The platform pays twice for return days and once-per-session fun: in ranking and in payout. A deep game that starts
slowly is penalised twice [inference].

## What the hits share

| Game | Loop | Social glue | Timed event | Source |
|---|---|---|---|---|
| Grow a Garden (22M CCU record) | plant → crops grow **offline** → sell → rarer seeds | pets, stealing neighbours' crops | weekly update; "admin abuse" weather on a schedule | [Wikipedia](https://en.wikipedia.org/wiki/Grow_a_Garden), [Digital Citizen](https://www.digitalcitizen.life/grow-a-garden-admin-abuse-schedule/) |
| Steal a Brainrot (25M CCU) | buy → passive income → steal rarer ones from other bases | theft, shield, traps | admin events with exclusive characters | [Wikipedia](https://en.wikipedia.org/wiki/Steal_a_Brainrot) |
| Adopt Me | hatch, raise, trade | a player-run pet economy; event pets appreciate | update days (1.9M CCU record) | [PocketGamer.biz](https://www.pocketgamer.biz/interview/76516/roblox-adopt-me-devs-launch-uplift-games/) |
| Pet Simulator 99 | currency → stronger pets → new areas | guilds, trading to fill a collection | — | [Earnaldo](https://earnaldo.com/blog/pet-simulator-x-vs-pet-simulator-99) |
| Dress to Impress | theme → dress against a timer → vote | the vote | every round | [mvstampede](https://mvstampede.net/6639/ae/dress-to-impress-the-tiktok-viral-fashion-game) |
| Fisch | cast → 400k fish variants → sell | collection | — | [RoWatcher](https://rowatcher.com/games/5750914919) |

Naavik's reading: Roblox hits are "proven F2P patterns the Roblox audience has never seen", re-skinned social
[opinion] ([Naavik](https://naavik.co/digest/predicting-the-next-big-hits-on-roblox/)). Kotaku called Grow a Garden
"more like a prototype than a finished game" and it still broke every record — polish is not what the audience is
buying [opinion] ([Wikipedia](https://en.wikipedia.org/wiki/Grow_a_Garden)).

Common denominator [inference]: **progress you can see in under a minute**, plus **bounded, reversible loss from
other players** (crop theft, base raids), plus a **shared moment** everyone logs in for. Lowlands has threat and a
world that moves; relative to these it lacks a personal thing that grows while you are away and can be shown or traded.

## Playing with friends

- Co-play is a ranking input: "average number of unique days that users come back to play your game with friends"
  [Roblox primary] ([Creator Hub: Discovery](https://create.roblox.com/docs/discovery)); Q3 2025 names "7-day
  intentional co-play days" as a signal ([Q3 2025 letter](https://www.sec.gov/Archives/edgar/data/1315098/000131509825000326/ex991-q32025shareholderl.htm)).
- `GetFriendsWhoPlayed` (GA June 2026) exists for friend panels and leaderboards; the announcement gives no retention
  statistic ([DevForum](https://devforum.roblox.com/t/beta-getfriendswhoplayed-api-build-scalable-friend-leaderboards-and-social-engagement-loops/4644214)).
- The "3× D1 / 5× D30 with a friend" multipliers are third-party and unsourced ([ROLearn](https://rolearn.dev/guidance/player-engagement-retention)). Treat as unverified.
- Relatedness independently predicts enjoyment and future play in an MMO sample [measured] ([Ryan, Rigby & Przybylski 2006](https://acuresearchbank.acu.edu.au/item/8q128/the-motivational-pull-of-video-games-a-self-determination-theory-approach)).

Because a 2D GUI world hides the avatar-centric social surfaces Roblox players expect, Lowlands has to do its own
work: friends' sprites with names, "Dan is at Kenstow" on join, and something to do together within seconds. Riding
as a pair (`RIDERS_MAX 2`) with the pot split is already designed [inference].

## Phones: check-ins, not sittings

- Roblox mobile guidance is principles, not numbers: Scale not pixels, readable fonts, test on real devices, prompts
  that reflect the active input ([Creator Hub: Adaptive design](https://create.roblox.com/docs/en-us/production/publishing/adaptive-design),
  [Cross-platform](https://create.roblox.com/docs/en-us/projects/cross-platform)). 44 px targets and ~14 pt text are
  general HIG conventions repeated by third parties ([creation.dev](https://www.creation.dev/blog/roblox-ui-design-best-practices)).
- The top decile of games gets 6–8 sessions a day [3rd-party measured]; the hits make each one a check-in with
  visible change since last time.
- "Over 24 experiences a month" means Lowlands competes for a slot in a rotation, not for an evening [inference].

For Lowlands: the first screen on return should be "what changed" (the `Headlines` card already exists), and the
session shape should be "do one meaningful thing in 5–10 minutes" (a hunt and sale, a ride, a camp before the
calamity). A game that only pays off in 45-minute sittings does not fit the rotation [inference].

## The first 60 seconds for Lowlands

What is on screen at t = 0 today: a plundered village, a bobbing arrow over the survivor, a banner "Someone is
calling you", and seven lines of text (`ideas/INBOX.md:165-173`, `Talk.lua:97-107`). The 30-second test passed with
Danzo (`docs/handoffs.md:52-53`). What the bounce metric asks for beyond that [inference]: something *alive* in the
frame before any reading (a villager running, a wolf at the edge, the caravan loading), one thing the knife or a
step can do within a screen, and a hint of a clock. The cold-start problem is structural for a memory-driven world:
the richness shows after an hour; the first minute has to show the *promise*.

## 2D on Roblox: thin evidence

DevForum treats 2D as a technical curiosity (BillboardGui, ImageLabel, ViewportFrame tricks); the only quantified
examples are small ("2D Basketball" 614 CCU peak; "Pixel Quest" 8.4K peak with 24-minute sessions but its rendering
style is unconfirmed) and no 2D title appears in any 2025 top list ([DevForum](https://devforum.roblox.com/t/can-i-make-a-2d-game/2185402),
[RoWatcher](https://rowatcher.com/games/6118057247/2d-basketball), [Rotrends](https://www.rotrends.com/game/7458874788/Pixel-Quest-GUILDS)).
The long tail growing 25% YoY is the strongest platform-level sign that a niche format can find an audience. Lowlands
would be defining its category; borrow the format-independent mechanics.

## Monetisation, briefly

Roblox frames shops and season passes as retention tools and does not warn about pay-to-win ([Creator Hub: Monetization](https://create.roblox.com/docs/en-us/production/game-design/monetization-foundations));
Steal a Brainrot drew pay-to-win criticism and Q2 2026 engagement shifted "to ... games with lower hourly
monetization" ([Wikipedia](https://en.wikipedia.org/wiki/Steal_a_Brainrot), [Q2 2026 letter](https://www.sec.gov/Archives/edgar/data/0001315098/000162828026051059/ex991-robloxq22026earnin.htm)).
For Lowlands, cosmetics (tribe garb, camp decorations, knife skins) and a free-track seasonal line fit without
touching standing or trade. Not urgent; the game is unpublished (`docs/design/build-rungs.md:40-62`).

## What this means for Lowlands

| Lever | Lowlands version | Where it already lives |
|---|---|---|
| First-five-minutes fun | something to chase or stab within a screen of spawn; the survivor's three doors | `Goals.lua`, `Ecology` spawn, H12 Option B |
| Visible change on return | "what changed for you" card + calamity countdown | `Headlines`, `Restore`, HUD clock |
| Timed shared event | the weekly calamity, telegraphed from the week's start, resolved offline with marks | `Calamity`, `Calendar` |
| Trading as talk | player-to-player trade in villages is a later rung; prices by word is toy #7 | `Trade`, `Gossip` |
| Co-play days | friend notice on join; ride as a pair; pot split | `Ride.lua`, `RIDERS_MAX` |
| Updates every 2–4 weeks | a new village hook, a new animal, a new calamity kind | the 16-village map gives room |

## Gaps

- No Roblox-authored D1/D7 benchmark, mobile share of hours, or friends→retention statistic exists.
- No design postmortem from the Grow a Garden or Steal a Brainrot teams; only business press.
- No 2D Roblox creator postmortem; "Pixel Quest" needs a visual check before being cited as a 2D example.
- No controlled study of text-heavy games' retention on Roblox; all of this is convention plus the bounce mechanics.
