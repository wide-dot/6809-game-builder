* Marker 1 — 2 KB, every byte carrying its number.
* Numbered from ONE : a marker full of zeroes cannot be told apart from RAM
* that was never written, and would pass the check for the wrong reason.
marker.0.begin EXPORT
 SECTION code
marker.0.begin
        fill  1,$0800
 ENDSECTION
