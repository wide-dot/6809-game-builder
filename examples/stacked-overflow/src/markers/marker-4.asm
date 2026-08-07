* Marker 5 — 2 KB, every byte carrying its number.
* Numbered from ONE : a marker full of zeroes cannot be told apart from RAM
* that was never written, and would pass the check for the wrong reason.
marker.4.begin EXPORT
 SECTION code
marker.4.begin
        fill  5,$0800
 ENDSECTION
