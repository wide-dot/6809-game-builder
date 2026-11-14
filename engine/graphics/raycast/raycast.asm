* ---------------------------------------------------------------------------
* raycast : the camera and the raycaster's calls, the resident part
* ---------------------------------------------------------------------------
* Included by the game mode with wallscaler.asm. The raycaster's code and
* tables are a unit of their own (raycast.unit.asm), its angles another
* file : this part mounts their pages.
*
* The camera, written by the game :
*   raycast.x, raycast.y   position, 8.8 cells ; cell (0,0) is the map's
*                          top left
*   raycast.angle          0-1023 a turn, 0 east (+x), 256 south (+y)
*
* Entries (A, B, X, Y, U and CC lost) :
*   raycast.cast   the camera's view to wallscaler.descriptors
*   raycast.move   B = a step along the camera's direction, signed, in
*                  1/256 cell : the camera moves where the map lets it and
*                  slides along a wall
* ---------------------------------------------------------------------------

raycast.unit.cast       EXTERNAL
raycast.unit.cast$PAGE  EXTERNAL
raycast.unit.move       EXTERNAL
raycast.angles          EXTERNAL
raycast.angles$PAGE     EXTERNAL
raycast.x               EXPORT
raycast.y               EXPORT
raycast.in              EXPORT

raycast.x      fdb   0
raycast.y      fdb   0
raycast.angle  fdb   0
raycast.in     fill  0,12                  ; the angle's rays : rd of column 0, the step
                                           ; between columns, the direction (s1.14)

raycast.cast
        _GetCartPageB                      ; the caller's page, given back
        pshs  b
        bsr   raycast.aim
        lda   #map.RAM_OVER_CART+raycast.unit.cast$PAGE
        _SetCartPageA
        ldu   #wallscaler.descriptors
        jsr   raycast.unit.cast
        puls  b
        _SetCartPageB
        rts

raycast.move
        _GetCartPageA                      ; the caller's page, given back
        pshs  a,b
        bsr   raycast.aim
        lda   #map.RAM_OVER_CART+raycast.unit.cast$PAGE
        _SetCartPageA
        ldb   1,s
        jsr   raycast.unit.move
        puls  a,b
        _SetCartPageA
        rts

; raycast.aim : the angle's 12 bytes to raycast.in (the angles' page mounted)
raycast.aim
        lda   #map.RAM_OVER_CART+raycast.angles$PAGE
        _SetCartPageA
        ldd   raycast.angle
        anda  #3                           ; 0-1023
        aslb
        rola
        aslb
        rola                               ; x 4
        pshs  d
        aslb
        rola                               ; x 8
        addd  ,s++                         ; x 12
        addd  #raycast.angles
        tfr   d,x
        ldu   #raycast.in
        ldd   ,x
        std   ,u
        ldd   2,x
        std   2,u
        ldd   4,x
        std   4,u
        ldd   6,x
        std   6,u
        ldd   8,x
        std   8,u
        ldd   10,x
        std   10,u
        rts
