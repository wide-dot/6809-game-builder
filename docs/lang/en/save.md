# Writing a file back to the disk : `writable` and `loader.file.save`

A game that keeps something between two sessions — a saved game, a high
score table, options — declares a file the loader may write back over its
own sectors, then reads it and writes it with two calls.

## Declaring it

```xml
<file name="save.data" codec="none" writable="true">
    <lwasm format="raw"><asm filename="src/data/save.asm"/></lwasm>
</file>
```

What the source assembles is the file's content on a fresh disk (an empty
save, a default table). The builder then :

- **stores it on whole sectors of its own**. Files are written back to back
  on the disk, a file's partial last sector being the next one's first ; a
  writable file skips a sector its predecessor began and its size is
  rounded up to 256 × n bytes (one sector at least), so the next file
  starts on a fresh sector. Writing it never touches a neighbour ;
- **publishes `<name>.dir`**, the id of the directory that lists it, next
  to `<name>` (its file id) in the directory's symbols ;
- **gives the target's loader `loader.FILE_WRITE`** : the line
  `loader.FILE_WRITE equ 1` in `gen/directories/locations.asm`, which the
  loader includes. A target without a writable file gets the loader it
  always had, byte for byte.

Refused at build, by name : a writable file with a codec (`codec="none"`
must be written — the loader writes what it is given, there is no codec
on the way back), with `linkdata` (nothing to relocate in a save), a scene
table, or a member of a `<collection>` (its members land where the packer
puts them).

## Reading and writing it

```asm
        _ram.data.set #loader.PAGE            ; the loader, in the data window
        _loader.dir.load #save.data.dir       ; its directory in memory
        _loader.file.load #save.data,#1,#buf  ; file id, page, address
        ...
        _loader.file.save #save.data,#1,#buf
        bcs   failed                          ; B : why
```

`loader.file.save` (jump table index 54) takes X = the file id, B = the
source page, U = the source address, and writes the file's sectors from
there — the whole stored size (the rounded one), so the RAM block is that
size. Like `loader.file.load`, it reads the file's entry from the directory
in memory : `_loader.dir.load` first (it prompts for the disk if another
one is in the drive).

**The disk is checked before the write.** `_loader.dir.load` does nothing
when the directory asked for is already in memory, so the player may have
changed the disk since. `loader.file.save` reads that directory again from
the drive (its `IDX` tag and its disk id, one directory read) before it
writes a byte : another disk, or none, goes through the insert-disk prompt,
and the write waits for the right one. The check knows the builder's
directories, not the game : another game built by this builder with the
same directory id passes it.

On return CC carry clear : written. Carry set : not written, and B says
why :

| B | |
|---|---|
| `$80` | the file cannot be written in place : not declared writable (compressed, or sharing a sector) |
| `$01` | the disk is write-protected |
| `$02` `$04` `$08` `$10` | the monitor's `DK.STA` : timing, sector, data, drive not ready |

A failed write is retried once, unless the disk is write-protected. A
failure in the middle leaves the sectors written so far : a save that must
survive a cut keeps two files and a sequence number, and reads the newest
valid one.

A disk change before the write (the player took the disk out) goes through
the loader's insert-disk prompt ; a game that wants it in its own screen
installs a prompt hook (`config.md`, *The game's prompt*).

## Cost

- In the loader, only with `loader.FILE_WRITE` : 172 bytes (169 of code,
  3 in the jump table).
- On the disk : the sectors the rounding adds, and at most one sector
  skipped before the file.
- At run time : the directory read again (one sector per directory sector),
  then the monitor's write, about one turn of the disk (200 ms)
  per sector (each call to DKCONT stops the motor on its way out, the
  next one restarts it).

## The monitor's write

`loader.file.save` goes through DKCONT (`$E004`), the monitor's disk
routine, as reads do. DKCONT dispatches on `DK.OPC` by its **lowest set
bit** : `$01` initialises, `$02` reads a sector, **`$08` writes one** (it
tests the write protection first, STAT1 bit 2, and returns `DK.STA $01`),
`$04` only sets a flag in the monitor's variables — it returns carry clear
without writing anything. Read from the TO8's disk ROM ; a table that gives
`$04` for a write is wrong for this machine.

The loader's partial-sector cache (`ptsec.key`) is invalidated by a
write : the next read of a sector the write covered goes to the disk.

## The bench

`examples/save` ([readme](../../../examples/save/readme.md)) boots on one
disk image four times under toje, the image mounted from its file with the
write protection off (toje writes the TO8's sector writes back into the
`.fd`) : `ci/toje-bench/save_ut.py`.
