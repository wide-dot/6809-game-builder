# A page is a register value, not a page number

`_SetCartPageA` writes its byte into `$E7E6` unchanged. A table of pages
therefore holds `map.RAM_OVER_CART+page`, not the bare page number.

## Symptom

The wrong bank is mounted, so code or data is read from whatever page number
`page` alone selects — with the overlay bit clear, that is not even the same
window. What follows is arbitrary.

## The v1 idiom

v1 wrote `page+$60`, which is the same value: `map.RAM_OVER_CART` is
`%01100000` = `$60`. The constant was spelled as a number rather than named.

## The v2 model

Identical hardware, named constant. Use `map.RAM_OVER_CART+page` so the two
bits that select the window are visible in the source.

For **generated** data the page is not known at assembly time, and comes from
the linker instead: the symbol `<direntry name>$PAGE`, an 8-bit `externPg`
relocation that accepts an addition operand — hence the `...$PAGE+$60` you see
in generated index files. The unit must include `entries.asm` so the file-id
equate exists.

Both forms coexist and mean the same thing:

```asm
        fcb   map.RAM_OVER_CART+enemies.page    ; region equate, assembly time
        fcb   common.enemies$PAGE+$60           ; link symbol, load time
```

Prefer the region equate when you have it — it reads better and costs no link
data. Use the `$PAGE` symbol when the page depends on where the builder chose
to put a direntry.

## The fix

Grep any hand-written page table for bare page numbers. In new code, write the
named constant.

## Proof

Read the mounted page at the point of use — under [toje][toje],
`read_page_map` gives the physical page behind each window, and a breakpoint
can be qualified by page so it only breaks on the intended bank.

[toje]: https://github.com/wide-dot/toje

## Met in

Recorded from the `sound/to8` pilot, 2026-07-31.
