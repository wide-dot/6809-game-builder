# R-Type Arcade — Audio command inventory

> Source of truth: the arcade `maincpu.bin` Ghidra database (x86 16-bit, code segment `0x40`),
> queried via the asm-ark bridge. Every address below is verbatim from that DB.
> Purpose: reference for porting the sound triggers to the Thomson TO8 version.
> Companion document: [`inventaire-sons.md`](inventaire-sons.md) — where our YM2413
> data comes from, what our port plays, and the mapping to the Master System corpus.

---

## 1. TL;DR

- Every sound in the game is requested by a single call: `enqueue_audio_cmd`
  (`0x40_0303`), which appends **one command id** to a 32-slot ring buffer.
- The id space is shared: **below `0x22` = music orchestration**, **`0x22` and
  above = sound effects**.
- **245 call sites** across the whole game. **232** pass an immediate
  (`MOV CL,imm8` or `XOR CL,CL`); **13** compute the id or read it from a table.
- **54 distinct effect ids** are posed by immediate, plus **8** reached only
  through the continue-countdown table (`0x72`–`0x79`) and **24** music codes
  reached only through the three per-stage music tables. **86 distinct ids** in
  all.
- The two busiest ids of the entire game are **`0x56`, the non-fatal enemy
  hit, at 39 sites**, and **`0x52`, the turret explosion, at 24 sites**. They
  are what gives the arcade its sound texture.
- The queue is a *request* channel only. The sound data itself lives in the
  Z80 sound CPU's own program, which is **not** part of this ROM set — so this
  document inventories *what the game asks for and when*, not the waveforms.

---

## 2. The audio pipeline

```
   game code
     MOV CL,<id>
     CALL enqueue_audio_cmd          0x40_0303
       -> ring buffer, 32 slots      0x42020
          read pos  [0x2EDC]
          write pos [0x2EDE]
     (queue full -> command silently dropped)

   once per frame
     dispatch_audio_cmd_queue        0x40_0320
       -> filtering (below)
       -> OUT $00                    M72 soundlatch
          -> Z80 sound CPU -> YM2151
```

### `enqueue_audio_cmd` (0x40_0303)

Interrupts are cleared for the critical section so a raster or VBlank IRQ
cannot dequeue mid-write. The write index advances modulo 32; if advancing
would meet the read index the slot is left alone and the position is **not**
committed — the request is dropped without a trace.

### `dispatch_audio_cmd_queue` (0x40_0320)

Dequeues **at most one** command per call and forwards it to the soundlatch.
Its filtering is worth knowing, because it means a request is not always
heard:

- read == write (empty) → nothing sent;
- a handful of per-frame routines installed at `[0x0000]` are *always allow*
  modes — the title-letter animation and the demo dispatcher slots (compared
  against `0x10FA`, `0x160F`, `0x1660`, `0x17D7`, `0x132A`, `0x136E`). When the
  current entrypoint is one of those, the command goes through unconditionally;
- otherwise `0` and `0x63` always go through, and **every other id is sent only
  when the Demo Sounds DIP is on** (`[0x2F2B] & 0x04`) **and** the id is `>= 0x22`.
  Music codes are therefore suppressed in the quiet modes;
- `pickup_pending_flag` (`[0x2F30]`) is cleared on every exit.

---

## 3. Music orchestration — ids below `0x22`

| Id | Event | Callers |
|---|---|---|
| `0x00` | **stop music** (`XOR CL,CL`) — title/demo sequencer transitions, intro palette init, and the player's death | `run_title_demo_sequencer` ×3, `intro_palette_init`, `FUN_0040_11E2`, `run_player_one` |
| `0x19` | **boss BGM start** — one cue shared by every boss; on Bydo it doubles as the maw-charge telegraph before the fireball volley | `spawn_dobkeratops`, `create_gomander`, `create_compiler`, `create_dop_swarm_boss`, `create_bellmite`, `tick_bronco_lifecycle_manager`, `bydo_attack_sfx_charge`, `tick_warship_master` |
| `0x1A` | **boss BGM stop** / death-transition rumble. The DB notes the old label "cancel rumble" was wrong: this is a music stop | 16 sites across the end-stage sequence, gomander, compiler death, dop swarm, bellmite, bronco, warship |
| `0x1B` | **stage-clear jingle / boss defeated**, and the second blast of the death sequence | `run_dobkeratops`, gomander `_death_second_blast`, `tick_compiler_death_sequence`, `end_boss_after_dop_swarm`, `tick_bronco_lifecycle_manager`, `tick_warship_master` |
| `0x1C` | secondary paired cue, always emitted right after `0x1A` or `0x1B` | 8 sites, same families |
| `0x1F` | game-intro music — played **once per session** (the first call never fires) | `play_stage_init_music` |
| `0x20` | boss-music fade-in marker (first call, one-shot gate `[0x2F45]`) | `play_boss_init_music_one_shot` |
| `0x21` | starts the level-music fade-out; the paired `0x20` is scheduled 384 frames later | `play_boss_announce_sfx_paired_one_shot` |

### The three per-stage music tables

Read with the id computed, not immediate — see §5. Indexed by
`stage_music_variant` (`[0x2FC5]`), ten entries each:

| Table | Address | Values |
|---|---|---|
| `stage_music_start_table` | `0x8C02` | 01, 0D, 04, 07, 0A, 01, 10, 13, 16, 01 |
| `stage_music_scheduled_transition_table` | `0x8C0C` | 02, 0E, 05, 08, 0B, 02, 11, 14, 17, 02 |
| `stage_music_immediate_transition_table` | `0x8C16` | 03, 0F, 06, 09, 0C, 03, 12, 15, 18, 03 |

So the music codes actually used are `0x01`–`0x18`, in triplets per stage:
start, scheduled transition, immediate transition.

---

## 4. Sound effects — ids `0x22` and above

### Cabinet and front-end

| Id | Event | Callers |
|---|---|---|
| `0x22` | game-over jingle (player dies on the last life) | `run_player_one`, `run_game_over_sequence` |
| `0x25` | `SFX_TITLE_ATTRACT_SCENE` — attract scene entry, second demo cycle | `run_title_demo_sequencer` |
| `0x26` | attract sting, at the switch to demo playback | `begin_attract_demo_audio` |
| `0x27` | `SFX_TITLE_LETTER_LANDED` — one title letter lands | `run_title_letters_wait` |
| `0x28` | `SFX_NAME_ENTRY_INTRO` — name-entry opening chime | `run_high_score_name_entry_setup` |
| `0x29` | wait after a letter is committed | `run_name_entry_post_commit_wait` |
| `0x2A` | full name entered / entry finished | `run_high_score_name_entry_input` |
| `0x40` | alphabet cursor move | `run_high_score_name_entry_input` ×2 |
| `0x41` | letter committed | `name_entry_commit_letter` |
| `0x63` | coin inserted | `award_credits` |

### Player armament and pickups

| Id | Event | Callers |
|---|---|---|
| `0x30` | `SFX_SIMPLE_FIRE` — basic shot; skipped when a pod of level ≥ 2 is already audible | `create_simple_fire` |
| `0x31` | charged beam released | `create_beam` |
| `0x32` | beam charge starts (charge level ≥ `0x0F`) | `create_charging_beam` |
| `0x33` | charge stops | `run_charging_beam` |
| `0x34` | `SFX_MISSILE_LAUNCH` | `create_top_missile` |
| `0x35` | player explosion (preceded by the `0x00` music stop) | `run_player_one` |
| `0x36` | `SFX_FORCE_POD_EJECT` | `run_force_pod_attached` |
| `0x37` | `SFX_FORCE_POD_ATTACH` | `run_force_pod_floating` |
| `0x38` | **1UP** — extra life on score | `update_current_stage_score` |
| `0x3A` | bonus pickup chime | `apply_bonus_pickup` |
| `0x3B` | reflex (rebound) laser fire **and bounce** — the bounce SFX is played by segment 2 only | `instantiate_diagonal_rebound_laser_up_right_2`, `..._down_right_2`, `instantiate_horizontal_rebound_laser_segment_2`, diagonal tick (`0x40_4359`), horizontal tick (`0x40_4529`) |
| `0x3C` | yellow ground-crawling laser fire | `arm_ground_laser_right_a`, `..._right_b`, `..._diag_a`, `..._diag_b` |
| `0x3D` | `SFX_COUNTER_AIR_LASER` — counter-air fire, two beam slots | `create_counter_air_laser_a`, `create_counter_air_laser_b` |
| `0x3F` | `SFX_FORCE_POD_SIMPLE_FIRE` — the reflections' shot | `run_counter_air_reflection` |

### Explosions and hits

| Id | Event | Sites |
|---|---|---|
| `0x50` | `SFX_EXPLOSION_BASE` — small explosion / generic impact | 11 — `create_bonus`, `run_pata_pata`, `run_mid`, `run_bug`, `run_tabrok_cannon`, `tabrok_missile_explode`, `run_pursuer`, `destroy_p_staff_rocket_1`, `run_scant_beam`, `outslay_bydo_shot_tick`, warship core fire emitter |
| `0x51` | heavy enemy-destruction explosion | 7 — `run_bink_destroy`, `run_cytron`, `destroy_p_staff`, `destroy_slither_body_or_tail`, `destroy_cancer`, `run_geld`, `tick_bronco_segment_state` |
| `0x52` | **turret explosion — the most used destruction sound of the game** | **24** — shell child, newt, blaster, brood, city panel ×3, zoid, outslay body, mikun, **dobkeratops optical nerves**, bellmite satellite, bronco chaser, and eleven warship parts |
| `0x53` | big explosion ("BIG bang", final core blast) | 12 — dop, tabrok, boldo, gouger, slither head, scant, cheetah, city panel finale, and four warship parts |
| `0x54` | Wick explosion | 1 — `run_wick` |
| `0x56` | **non-fatal hit taken by an enemy or a boss part — the most frequent sound of the game** | **39** — dop collision, tabrok ×9 states, cytron, shell child, boldo, newt, p-staff ×5 states, scant ×2, cheetah, **compiler right/bottom/main ×3**, bronco segment, and sixteen warship parts |
| `0x57` | second hit sound (boss ping / armoured enemy) | 23 — gouger ×3, slither ×6, brood ×6, zoid parasite, dobkeratops monster, gomander engulf, bellmite combat, bellmite satellites ×3, bydo |

### Enemy fire and manoeuvres

| Id | Event | Callers |
|---|---|---|
| `0x55` | score rollover | `tick_score_rollover_dispatcher` |
| `0x59` | enemy laser fire (compiler volleys, Scant beam, horizontal laser) | `mid_spawn_horizontal_laser_child`, `scant_shoots`, `spawn_blaster_horizontal_laser_child`, `compiler_right_laser_volley_spawner`, `compiler_left_laser_volley_spawner`, `tick_warship_escape_capsule_in_place` |
| `0x5A` | warship rear-reactor ejection charge | `tick_warship_rear_reactor_body` |
| `0x5B` | rear reactor destroyed (immediately followed by `0x52`) | `tick_warship_rear_reactor_body` |
| `0x5D` | heavy enemy fire / volley; on `create_zoid` it is the Zoid **emergence** sound | tabrok cannon projectile spawner, `tabrok_shoots_4_missiles`, `p_staff_shoots_rocket`, `create_zoid`, `outslay_fire_bydo_shot_8way`, `compiler_left_rolling_laser_spawner`, `tick_warship_front_turret`, warship core boss-fire emitter |
| `0x5E` | emitted from the main IRQ loop; no further comment in the DB | `irq_main_loop` |
| `0x5F` | `SFX_GOUGER_TRAIL` / Gomander orb pellet emission | `run_gouger`, `tick_gomander_orb_pellet_run` |
| `0x61` | `SFX_TABROK_TAKEOFF`; also the bottom reactor's flame ejection | `missile_launch_swap_handler`, `tick_warship_bottom_reactor` |
| `0x62` | `SFX_OPTICAL_NERVE_DESTROY` — a Dobkeratops optic nerve dies | `dobkeratops_erase_optical_nerves` |
| `0x64` | scene-entry announce (Mikun variants B/C/D — variant A is silent); also Dobkeratops fire | Mikun spawns ×3, `run_dobkeratops_fire` |
| `0x65` | a Bronco auxiliary fighter appears | `tick_bronco_helper_periodic_spawner` |
| `0x66` | Bronco main-attack phase transition | `tick_bronco_main_attack_subchild_phase1` |
| `0x67` | cyclic cue every `0x180` frames during the Bronco attack | `tick_bronco_helper_main_attack` |
| `0x68` | Bronco frame-transition cue; Bydo fireball emission | `run_bronco` ×2, `bydo_attack_fireball_a` |
| `0x2B` | Bydo death final stinger | `run_bydo` |

---

## 5. The thirteen computed ids

Sites that do not pass an immediate. Twelve are explosion cascades that roll a
die; the thirteenth is the countdown.

| Site | Routine | What it resolves to |
|---|---|---|
| `0x40_1429` | `stage_cleared_advance_digit` | `MOV CX,ES:[BX+0xDE0]`, BX = digit cursor ×2. The table at `0x1000_0DE0` (interleaved stride 4 with the tile table at `0x0DDE`) holds `0x0079, 0x0078, 0x0077, 0x0076, 0x0075, 0x0074, 0x0073, 0x0072` — so **`0x72`–`0x79`, one beep per continue-countdown digit** |
| `0x40_9D46` | `dobkeratops_explosion` | `CL=0x50`, then `AND AL,3` / `JZ skip` / `ADD CL,AL` → `0x51`/`0x52`/`0x53`, one chance in four of silence |
| `0x40_A12A` | `dobkeratops_delayed_explosion` | same shape → `0x51`/`0x52`/`0x53`, 1/4 silent |
| `0x40_A6C6` | `tick_gomander_death_explosion_cascade` | `AND AL,6` / `SHR` / base `0x50` → `0x51`/`0x52`/`0x53`, 25 % silent, every 4 frames |
| `0x40_B08D` | `compiler_part_destroy_with_explosion_cascade` | base `0x52` + random bit → `0x52`/`0x53` |
| `0x40_B4A8` | `tick_bellmite_death_helper` | `AND AL,1` / base `0x52` → `0x52`/`0x53` (a sound-only helper, no sprite) |
| `0x40_BFFA` | `tick_bronco_helper_main_attack_fade` | base `0x52` + bit → `0x52`/`0x53` |
| `0x40_C298` | `tick_bydo_death_explosion_cascade` | `AND AL,6` / `SHR` / base `0x50` → `0x51`/`0x52`/`0x53`, on 75 % of the firing frames |
| `0x40_DEF1` | `tick_warship_core_destroy_explosion_chain` | `AND AL,4` / `SHR 2` / base `0x52` → `0x52`/`0x53` |
| `0x40_F3D1` | `tick_sfx_followup_timer` | `MOV CX,[BP+0x12]` — the command was stored by the spawner (`0x40_F366`). In practice always a **music** command: `0x20` on the first shot, otherwise a byte of `stage_music_scheduled_transition_table` |
| `0x40_F3FB` | `play_stage_init_music` | `stage_music_start_table` (`0x8C02`) |
| `0x40_F425` | `play_boss_init_music_one_shot` | `stage_music_scheduled_transition_table` (`0x8C0C`) |
| `0x40_F3A4` | `play_boss_announce_sfx_paired_one_shot`, alternate path | `stage_music_immediate_transition_table` (`0x8C16`) |

The cascade pattern is worth keeping in mind for the port: a boss dying does
not play one explosion, it plays a **stream** of them, one every few frames,
each drawn at random from three tiers with a one-in-four chance of silence.
That is what makes an arcade boss death sound dense rather than repetitive.

---

## 6. Ids never referenced

`0x23`, `0x24`, `0x2C`–`0x2F`, `0x39`, `0x3E`, `0x42`–`0x4F`, `0x58`, `0x5C`,
`0x60`, `0x69`–`0x71`.

These are gaps in the *request* space: no code path asks for them. Whether the
sound CPU holds data for them cannot be answered from this ROM set — R-Type's
Z80 program is not among the twenty files of `rtype.zip`, and MAME's `rtype`
set does not include it either. Consequently **this inventory is the list of
sounds the game asks for, not the list of sounds the board can make**, and the
count of ids here is a lower bound on the arcade's catalogue.

---

## 7. Totals

| | |
|---|---|
| call sites to `enqueue_audio_cmd` | 245 |
| with an immediate id | 232 |
| with a computed or table-read id | 13 |
| distinct effect ids by immediate | 54 |
| distinct ids in all (with the countdown and music tables) | 86 |
| busiest id | `0x56`, enemy hit, 39 sites |
| second busiest | `0x52`, turret explosion, 24 sites |

For what our port plays today, what is missing, and the correspondence with
the Master System sound corpus, see [`inventaire-sons.md`](inventaire-sons.md).
