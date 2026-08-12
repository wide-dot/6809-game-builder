* The collection's unit : one indivisible element among the tiles.
*
* Eight authored bytes the game mode verifies on machine, then one
* link-resolved pointer to a tile of the SAME collection — when the packer
* lands this unit and that tile in different members, the pointer is only
* right if the member's merged link data was rebased correctly.
mixed.table EXPORT
adr_assets.mixed_1_ND0 EXTERNAL

 section code

mixed.table
        fcb   $C0,$1E,$C7,$10,$A5,$5A,$3C,$99
        fdb   adr_assets.mixed_1_ND0

 endsection
