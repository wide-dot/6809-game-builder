# Benches

An example that proves an engine capability is a **bench** : a game mode that
exercises the capability, writes its verdicts in RAM, and is replayed headless
under toje against a reference committed with it. One command replays them
all : `ci/run-benches.sh`.

## The witnesses

At `$9C00` unless the bench says otherwise, N the bench's number of tests :

| Offset | Content |
|---|---|
| `+0` | `$CA` once the game mode runs |
| `+1` | N |
| `+2` | `$0D` once the sequence completed |
| `+3` .. `+2+N` | one byte per test, rank order : `$01` pass |
| then N words | one per test, rank order : a value the test recorded (a VRAM checksum), 0 if none |

The block takes 3 + 3N bytes. A bench may write more after its sequence (a
block of measures) : it names the block and the byte that says it is
complete.

## bench.json

Next to the example's `to8.config.xml` :

```json
{
  "disk": "dist/to8.fd",
  "witnesses": "9C00",
  "tests": 39,
  "blocks": {"sweep": ["9D00", 256]},
  "until": [["9DFE", "CB"]],
  "frames": 2000
}
```

`disk` may be a list : an example's targets (one per set of options) run
the same tests, each line of `bench.ref` prefixed with its disk's name
(`examples/tilemap`).

`tests` is checked against N in RAM : a bench that did not run all its tests
fails. `blocks` are read whole once every `until` byte holds its value ;
`frames` bounds the wait.

## bench.ref

The reference : every test's result and word, then each block in lines of 32
bytes. The verdict is every test at `$01` **and** every line identical to the
reference. A changed word is a changed picture : a bug, or a change meant —
then `--update` writes the new reference, committed with the change that
explains it.

```bash
python3 ci/toje-bench/bench.py examples/overlay             # verdict
python3 ci/toje-bench/bench.py examples/overlay --update    # new reference
ci/run-benches.sh [--no-build]                              # every bench
```

Exit codes : 0 pass, 1 fail, 2 no verdict (the sequence never completed).

## Writing a bench

- Generated art only (a test pattern, see `examples/*/tools/gen_*.py`).
- Each test resets what it uses, runs the capability once, and checks what can
  be checked : flags, the rows drawn, a checksum. A test that compares two paths
  (a multisprite child against the same image drawn by the single path) proves
  more than one that only records.
- Prove the bench catches what it guards : break the code on purpose once, see
  the test fail, restore.
