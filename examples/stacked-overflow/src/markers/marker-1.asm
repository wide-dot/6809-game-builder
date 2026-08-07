* Marker 2 — 2 KB, every byte carrying its number.
* Numbered from ONE : a marker full of zeroes cannot be told apart from RAM
* that was never written, and would pass the check for the wrong reason.
marker.1.begin EXPORT
 SECTION code
marker.1.begin
        fill  2,$0800
 ENDSECTION
