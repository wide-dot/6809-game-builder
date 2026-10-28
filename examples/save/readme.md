# save — a file written back to the disk

The bench of `<file writable="true">` and `loader.file.save`
([manual](../../docs/lang/en/save.md)) : a game writes a file back over its
own sectors and finds it again at the next boot.

One resident game mode, nothing on screen. At each boot it :

1. loads `save.data` (300 bytes declared, stored on two whole sectors) and
   checks its signature `SAVE` ;
2. reads the boot count (byte 4), adds one, fills the rest of the 512 bytes
   with a sequence that starts at the count ;
3. writes it back with `loader.file.save`, then reads it again from the
   disk and compares it with what it wrote ;
4. loads `before.data` and `after.data`, the raw files declared on each
   side of it (100 bytes of `$A5`, of `$5A`), and checks them ;
5. asks `loader.file.save` to write `before.data`, not declared writable :
   refused, `$80`.

On the disk : `before.data` from the first sector of `DATA`, `save.data` on
the next two sectors (the one `before.data` began is skipped), `after.data`
on a fresh sector after them.

## Build

```
ln -s ../../engine engine      # once
java -Dbasedir=<repo root> -cp "../../repo/*" \
     com.widedot.m6809.gamebuilder.MainCommand -f to8.config.xml
```

Output in `dist/to8.fd`.

## Witnesses at `$9C00`

| | |
|---|---|
| `+0` | `$CA` while running, `$0D` once done |
| `+1` | the boot count read at this boot |
| `+2` | 1 : the signature read |
| `+3` | `loader.file.save` : 0 written, else its B |
| `+4` | 1 : read back as written |
| `+5` | the boot count read back |
| `+6` | 1 : the neighbours as declared |
| `+7` | `loader.file.save` on `before.data` : its B (`$80`) |

## The bench

```
python3 ci/toje-bench/save_ut.py examples/save
```

A copy of `dist/to8.fd` mounted from its file, write protection off, four
boots with a reset between them (the disk stays in) : the first boot reads
count 0, writes 1 and finds it back, and exactly two sectors of the image
file change, holding what the game wrote ; the second reads 1 ; the third,
write-protected, gets `DK.STA $01` and reads 2 ; the fourth, unprotected
again, still reads 2.

Result on 28/10/2026 : **BENCH save PASS : 8/8** (toje 1.9.0).
