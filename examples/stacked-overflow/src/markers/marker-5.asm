* Marker 6 — 2 KB, every byte carrying its number.
* Numbered from ONE : a marker full of zeroes cannot be told apart from RAM
* that was never written, and would pass the check for the wrong reason.
marker.5.begin EXPORT
 SECTION code
marker.5.begin
        fill  6,$0800
 ENDSECTION
