* Marker 3 — 2 KB, every byte carrying its number.
* Numbered from ONE : a marker full of zeroes cannot be told apart from RAM
* that was never written, and would pass the check for the wrong reason.
marker.2.begin EXPORT
 SECTION code
marker.2.begin
        fill  3,$0800
 ENDSECTION
