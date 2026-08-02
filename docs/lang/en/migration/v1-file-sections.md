# Where to include a v1 file that has no `SECTION`

Include v1 files **inside** the game mode's section. Kept-v2 files, which carry
their own `SECTION`, go after `ENDSECTION`.

## Symptom

Assembly errors about nesting, or bytes landing in a section you did not
intend.

## The v1 idiom

v1 files carry no `SECTION` at all — an absolute image has one implicit
section, so the directive had no purpose.

## The v2 model

A relocatable unit is made of named sections, and the builder places each one.
A file that declares no section contributes to whichever one is open; a file
that declares its own must not be nested inside another.

That splits the include list in two:

```asm
 SECTION code
        INCLUDE "engine/... "        ; v1 files, no SECTION of their own
        ...
 ENDSECTION
        INCLUDE "engine/... "        ; kept-v2 files, carrying their SECTIONs
```

## The fix

Sort the includes by origin. The manifest tells you which is which: a file with
a v1 import line has no section, a `KEPT-V2:` file has its own.

## Proof

The build passes and the map shows each symbol in the expected section.

## Met in

Recorded from the `sound/to8` pilot, 2026-07-31.
