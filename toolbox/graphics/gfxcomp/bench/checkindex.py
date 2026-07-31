"""Compare the imageset index gfxcomp emits with what the v1 encoders measured.

The index is what the runtime actually reads, and it is where the port's three
silent defects lived (truncated addresses, invented page symbols, missing
cartridge bits). Geometry has to match exactly ; the cell count is expected to
differ, because the v2 erase margin is 12 bytes where v1 used 16 — a tracked
deviation, so the bench asserts the v2 value rather than flagging the gap.

usage: checkindex.py <index.asm> <name> "x1=.. y1=.. xs=.. ys=.. eraseData=.."
"""
import re
import sys


def rows(text, label):
    """the fcb/fdb rows of one image, from its set_ label to the next label

    The label is matched on its own line : the file opens with an interface
    block where the same name appears followed by EXPORT.
    """
    m = re.search(r"^set_" + re.escape(label) + r"\s*$", text, re.M)
    rest = text[m.end():]
    end = re.search(r"^\w+\s+equ\s", rest, re.M)
    return [r.strip() for r in (rest[:end.start()] if end else rest).splitlines() if r.strip()]


def bytes_of(row):
    return [f.strip() for f in row.split(None, 1)[1].split(",")] if row.startswith("fcb") else []


def val(field):
    return int(field.lstrip("$"), 16)


def signed(field):
    v = val(field)
    return v - 256 if v > 127 else v


index, name, geometry = sys.argv[1], sys.argv[2], sys.argv[3]
v1 = dict(re.findall(r"(\w+)=(-?\d+)", geometry))
text = open(index).read()

header = bytes_of(rows(text, name)[0])
subset = bytes_of(rows(text, name)[1])

got = {"xs": val(header[4]), "ys": val(header[5]),
       "x1": signed(subset[4]), "y1": signed(subset[5])}

bad = []
for key in ("xs", "ys"):
    if got[key] != int(v1[key]):
        bad.append(f"{key}: index {got[key]}, v1 {v1[key]}")

# the sub set stores the top left corner relative to the image center, which
# the v1 generator reports as the same pair
for key in ("x1", "y1"):
    if got[key] != int(v1[key]):
        bad.append(f"{key}: index {got[key]}, v1 {v1[key]}")

if "eraseData" in v1:
    cells = [bytes_of(r) for r in rows(text, name) if r.startswith("fcb")]
    nb_cell = val(cells[-1][0])
    expected = (int(v1["eraseData"]) + 12 + 63) // 64
    v1_cells = (int(v1["eraseData"]) + 16 + 63) // 64
    if nb_cell != expected:
        bad.append(f"nb_cell: index {nb_cell}, expected {expected} for {v1['eraseData']} erase bytes")
    note = f", nb_cell {nb_cell} (v1 would say {v1_cells}, margin 12 vs 16)"
else:
    note = ""

if bad:
    print(f"FAIL  {name} index : " + " ; ".join(bad))
    sys.exit(1)

print(f"PASS  {name} index : geometry matches v1 ({got['xs']}x{got['ys']}, "
      f"corner {got['x1']},{got['y1']}){note}")
