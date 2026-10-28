#!/usr/bin/env python3
"""
The bench of loader.file.save : examples/save booted four times on one disk image.

    python3 ci/toje-bench/save_ut.py examples/save

The example's game mode reads save.data (a <file writable="true">), counts the
boot in it, writes it back with loader.file.save, reads it again, checks that
the raw files declared around it are untouched and that a file not declared
writable is refused ; its witnesses are at $9C00 (examples/save/readme.md).

The image is a copy of dist/to8.fd, mounted from its file with the write
protection off (toje rewrites the sectors the TO8 writes into the file), and
the machine is reset between two boots, the disk left in place :

1. the first boot : the signature read, boot count 0, written (0), read back
   as written (count 1), the neighbours intact, before.data refused ($80) ;
   in the image file, exactly two sectors changed : save.data's, holding
   what the game wrote ;
2. a reset : boot count 1 (the first boot's write is on the disk), count 2
   written and read back ;
3. the write protection on, a reset : the write refused with the monitor's
   status $01 (write protected), nothing read back but what the disk held
   (count 2) ;
4. the protection off, a reset : boot count still 2.

Exit code : 0 pass, 1 fail.
"""
import os
import shutil
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mcp import Toje  # noqa: E402

WITNESS = 0x9C00
NAMES = ('magic', 'boots', 'signed', 'saved', 'readback', 'counted', 'around', 'refused')
SECTOR = 256


def boot(t, frames=4000):
    """Reset the machine (disk in place), boot from the floppy, run until the game is done."""
    t.call('reset')
    t.call('run_frames', {'n': 100})
    t.press('0F', 5)
    for _ in range(frames // 25):
        t.call('run_frames', {'n': 25})
        if t.read('%04X' % WITNESS, 1)[0] == 0x0D:
            break
    return dict(zip(NAMES, t.read('%04X' % WITNESS, len(NAMES))))


def changed_sectors(before, after):
    return [k for k in range(0, len(before), SECTOR) if before[k:k + SECTOR] != after[k:k + SECTOR]]


def main(args):
    example = os.path.abspath(args[0] if args else 'examples/save')
    tmp = tempfile.mkdtemp()
    image = os.path.join(tmp, 'save.fd')
    shutil.copy(os.path.join(example, 'dist', 'to8.fd'), image)
    original = open(image, 'rb').read()
    results = []

    def check(name, ok, detail):
        results.append(ok)
        print('%-40s %s  %s' % (name, 'PASS' if ok else 'FAIL', detail), flush=True)

    t = Toje()
    try:
        t.call('set_pointer_device', {'device': 'none'})
        t.call('mount_disk', {'path': image, 'write_protect': False})

        w = boot(t)
        check('boot 1 : read, counted, written', w['magic'] == 0x0D and w['signed'] == 1
              and w['boots'] == 0 and w['saved'] == 0, str(w))
        check('boot 1 : read back as written', w['readback'] == 1 and w['counted'] == 1, str(w))
        check('boot 1 : the neighbours intact', w['around'] == 1, str(w))
        check('boot 1 : a file not writable refused', w['refused'] == 0x80, 'B $%02X' % w['refused'])
        after = open(image, 'rb').read()
        sectors = changed_sectors(original, after)
        data = b''.join(after[k:k + SECTOR] for k in sectors)
        check('boot 1 : two sectors of the image changed', len(sectors) == 2 and b'SAVE\x01' in data,
              'sectors at %s' % ['$%05X' % k for k in sectors])

        w = boot(t)
        check('boot 2 : the first write on the disk', w['boots'] == 1 and w['saved'] == 0
              and w['readback'] == 1 and w['counted'] == 2, str(w))

        t.call('set_write_protect', {'on': True})
        w = boot(t)
        check('boot 3 : write protected, refused', w['saved'] != 0 and w['saved'] & 0x01 == 1
              and w['counted'] == 2 and w['readback'] == 0, 'DK.STA $%02X, %s' % (w['saved'], w))

        t.call('set_write_protect', {'on': False})
        w = boot(t)
        check('boot 4 : nothing written while protected', w['boots'] == 2, str(w))
    finally:
        t.close()
        shutil.rmtree(tmp, ignore_errors=True)
    ok = all(results)
    print('BENCH save %s : %d/%d' % ('PASS' if ok else 'FAIL', sum(results), len(results)))
    sys.exit(0 if ok else 1)


if __name__ == '__main__':
    main(sys.argv[1:])
