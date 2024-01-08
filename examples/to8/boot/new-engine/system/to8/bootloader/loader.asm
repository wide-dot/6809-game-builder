;*******************************************************************************
; FD File loader
; Benoit Rousseau 07/2023
; Based on loader from Prehisto (file load routine)
; ------------------------------------------------------------------------------
; A fully featured boot/file loader
; - zx0 compressed files
; - dynamic link of lwasm obj files
; - scene management
; - directory management
; - multiple floppy management
;
; TODO :
; - gérer le cas des fichiers vides, mais qui ont un fichier de link associé
;   ex: equates exportées
;
;*******************************************************************************
 SETDP $ff
        INCLUDE "new-engine/constant/types.const.asm"
        INCLUDE "engine/macros.asm"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/system/to8/map.const.asm"
        INCLUDE "new-engine/system/to8/bootloader/loader.const.asm"

; directory structure
; -------------------
dirheader STRUCT
tag     rmb types.BYTE*3 ; [I] [D] [X]
diskid  rmb types.BYTE   ; [0000 0000]              - [disk id 0-255]
nsector rmb types.BYTE   ; [0000 0000]              - [nb of sectors for direntries]
        ENDSTRUCT

; direntry main structure
; -----------------------
direntry STRUCT
bitfld   rmb 0            ; alias to bitfld
sizeu    rmb types.WORD   ; [0]                     - [compression 0:none, 1:packed]
                          ; [0]                     - [load time linker 0:no, 1:yes]
                          ; [00 0000] [0000 0000]   - [uncompressed file size -1]
track    rmb types.BYTE   ; [0000 000]              - [track 0-128]
                          ; [0]                     - [face 0-1]
sector   rmb types.BYTE   ; [0000 0000]             - [sector 0-255]
sizea    rmb types.BYTE   ; [0000 0000]             - [bytes in first sector (empty file: $ff00)]
offseta  rmb types.BYTE   ; [0000 0000]             - [start offset in first sector (0: no sector)]
nsector  rmb types.BYTE   ; [0000 0000]             - [full sectors to read]
sizez    rmb types.BYTE   ; [0000 0000]             - [bytes in last sector (0: no sector)]

; direntry compress structure
; ---------------------------
coffset  rmb types.WORD   ; [0000 0000] [0000 0000] - [offset to compressed data]
cdataz   rmb types.BYTE*6 ; [0000 0000]             - [last 6 bytes of uncompressed file data]

; direntry linker structure
; -------------------------
lsize    rmb types.BYTE   ; [0000 0000] [0000 0000] - [linker data size]
ltrack   rmb types.BYTE   ; [0000 000]              - [track 0-128]
                          ; [0]                     - [face 0-1]
lsector  rmb types.BYTE   ; [0000 0000]             - [sector 0-255]
lsizea   rmb types.BYTE   ; [0000 0000]             - [bytes in first sector]
loffseta rmb types.BYTE   ; [0000 0000]             - [start offset in first sector (0: no sector)]
lnsector rmb types.BYTE   ; [0000 0000]             - [full sectors to read]
lsizez   rmb types.BYTE   ; [0000 0000]             - [bytes in last sector (0: no sector)]
        ENDSTRUCT

        org   loader.ADDRESS
        jmp   >loader.scene.loadDefault  ; OK
        jmp   >loader.scene.apply        ; OK
        jmp   >loader.dir.load           ; OK
        jmp   >loader.file.load          ; OK
        jmp   >loader.file.malloc        ; OK
        jmp   >loader.file.unload        ; TODO

; callbacks that can be modified by user at runtime
error   jmp   >dskerr     ; Called if a read error is detected
pulse   jmp   >return     ; Called after each sector read (ex. for progress bar)

        INCLUDE   "new-engine/memory/tlsf.asm"

; temporary space
; ---------------
ptsec      fill  0,256 ; Temporary space for partial sector loading
diskid     fcb   0     ; Disk id
nsect      fcb   0     ; Sector counter
track      fcb   0     ; Track number
sector     fcb   0     ; Sector number

; directory
; ---------
loader.dir fdb   0

;-----------------------------------------------------------------
; loader.scene.loadDefault
;
;-----------------------------------------------------------------
; Load and run the default scene at boot time
; settings can be overided by defines at build time
;-----------------------------------------------------------------
loader.scene.loadDefault

        ; init allocator
        ldd   #loader.DEFAULT_DYNAMIC_MEMORY_SIZE
        ldx   #loader.memoryPool
        jsr   tlsf.init

        ; load directory entries
        lda   #loader.DEFAULT_SCENE_DIR_ID
        jsr   loader.dir.load

        ; load default scene files
        ldx   #loader.DEFAULT_SCENE_FILE_ID
        jsr   loader.file.malloc

        ldb   #loader.PAGE
        jsr   loader.file.load

        ; batch load files from disk, before decompression
        ; to benefit from sector interlacing
        ldx   #loader.file.load
        stx   loader.scene.routine
        jsr   loader.scene.apply

        ldx   #loader.file.decompress
        stx   loader.scene.routine
        jsr   loader.scene.apply

        ldx   #loader.file.link
        stx   loader.scene.routine
        jsr   loader.scene.apply

        jsr   tlsf.free

        ldb   #loader.DEFAULT_SCENE_EXEC_PAGE
        ldu   #loader.DEFAULT_SCENE_EXEC_ADDR
        jsr   switchpage
        jmp   loader.DEFAULT_SCENE_EXEC_ADDR

;-----------------------------------------------------------------
; loader.file.malloc
;
; input  REG : [X] file id
; output REG : [U] ptr to allocated memory
;-----------------------------------------------------------------
; Allocate memory for a file
;-----------------------------------------------------------------
loader.file.malloc
        pshs  x
        jsr   loader.dir.getFile

        ldd   direntry.sizea,y  ; Check for empty file flag
        cmpd  #$ff00
        bne   >
        ldu   #0                ; If file is empty, return 0
        rts
!
        ldd   direntry.sizeu,y  ; Read file data size
        anda  #%00111111        ; File size is stored in 14 bits
        addd  #1                ; File size is stored as size-1
        jsr   tlsf.malloc
        puls  x,pc


;-----------------------------------------------------------------
; loader.scene.apply
;
; input  REG : [U] ptr to scene data
; input  VAR : [loader.scene.routine] routine to run against files
;-----------------------------------------------------------------
; Apply a scene by loading files to RAM
; 3 different entry types can be combined in a scene.
; endmarker is type: %00
;-----------------------------------------------------------------

; scene structure
; ---------------
scene.header STRUCT
type     rmb 0
nbfiles  rmb types.WORD   ; [00]                     - [00:endmarker, 01:list of dest and id, 10:ajdacent dest and list of id, 11:adjacent dest and id]
                          ; [00 000] [0000 000]      - [nb files]
        ENDSTRUCT

scene   STRUCT
page     rmb types.BYTE   ; [0000 000]               - [page]
address  rmb types.WORD   ; [0000 000] [0000 000]    - [dest address]
fileid   rmb types.WORD   ; [0000 000] [0000 000]    - [file id]
        ENDSTRUCT

loader.scene.routine   fdb 0
loader.scene.fileCount fdb 0

loader.scene.apply
        ; parse scene data and load dir/files
        pshs  b,x,u
        leay  ,u
        
        ; a scene contains a list of blocks with a certain type
        ; a block type of 0 is the end marker
@nextblock
        lda   scene.header.type,y
        anda  #%11000000
        bne   >
        puls  b,x,u,pc                  ; end marker %00 found, return
!
        cmpa  #%01000000
        bne   >
        jsr   loader.scene.apply.type01
        bra   @nextblock
!       cmpa  #%10000000
        bne   >
        jsr   loader.scene.apply.type10
        bra   @nextblock
!       jsr   loader.scene.apply.type11
        bra   @nextblock

;-----------------------------------------------------------------
; loader.scene.apply.type01
;-----------------------------------------------------------------
; type %01 | nb files (0-16383)
; dest page \
; dest addr  - n times (for each file)
; file id   /
;-----------------------------------------------------------------

loader.scene.apply.type01
        ldd   scene.header.nbfiles,y
        leay  sizeof{scene.header},y
        anda  #%00111111
        std   loader.scene.fileCount
@loop
        ldb   scene.page,y
        ldu   scene.address,y
        ldx   scene.fileid,y
        jsr   [loader.scene.routine]
        leay  sizeof{scene},y
        ldd   loader.scene.fileCount
        subd  #1
        std   loader.scene.fileCount
        bne   @loop
        rts

;-----------------------------------------------------------------
; loader.scene.apply.type10
;-----------------------------------------------------------------
; type %10 | nb files (0-16383)
; dest page
; dest addr
; file id - n times (for each file)
;-----------------------------------------------------------------

loader.scene.apply.type10
        ldd   scene.header.nbfiles,y
        leay  sizeof{scene.header},y
        anda  #%00111111
        std   loader.scene.fileCount
        ldb   scene.page,y
        ldu   scene.address,y
        leay  scene.fileid,y
@loop
        ldx   ,y++               ; Read file id
        pshs  b,y                ; Save page id [b] and current scene data cursor [y]
;
        jsr   loader.dir.getFile
        ldd   direntry.sizeu,y   ; Read file data size
        anda  #%00111111         ; File size is stored in 14 bits
        addd  #1                 ; File size is stored as size-1
        std   @size
        leay  d,u                ; Will the file fit the page ?
        puls  b                  ; Restore page id
        cmpy  #$4000             ; Branch if data fits memory page
        bls   >
        ldu   #0                 ; else move to next page
        incb
 IFDEF boot.CHECK_MEMORY_EXT
        cmpb  #31
 ELSE
        cmpb  #15
 ENDC
        bls   >
        bra   *                  ; no more memory !
!
        jsr   [loader.scene.routine]
        leau  $1234,u
@size   equ   *-2
        puls  y
;
        ldx   loader.scene.fileCount
        leax  -1,x
        stx   loader.scene.fileCount
        bne   @loop
        rts

;-----------------------------------------------------------------
; loader.scene.apply.type11
;-----------------------------------------------------------------
; type %11 | nb files (0-16383)
; dest page
; dest addr
; start file id
;-----------------------------------------------------------------

loader.scene.apply.type11
        ldd   scene.header.nbfiles,y
        leay  sizeof{scene.header},y
        anda  #%00111111
        std   loader.scene.fileCount
        ldb   scene.page,y
        ldu   scene.address,y
        ldx   scene.fileid,y
        leay  sizeof{scene},y
        pshs  y
@loop
        stb   @b1                ; Save page id [b]
;
        jsr   loader.dir.getFile
        sty   @y
        ldd   direntry.sizeu,y   ; Read file data size
        anda  #%00111111         ; File size is stored in 14 bits
        addd  #1                 ; File size is stored as size-1
        std   @size
        leay  d,u                ; Will the file fit the page ?
        ldb   #0                 ; Restore page id
@b1     equ   *-1
        cmpy  #$4000             ; Branch if data fits memory page
        bls   >
        ldu   #0                 ; else move to next page
        incb
 IFDEF boot.CHECK_MEMORY_EXT
        cmpb  #31
 ELSE
        cmpb  #15
 ENDC
        bls   >
        bra   *                  ; no more memory !
!
        jsr   [loader.scene.routine]
        leau  $1234,u
@size   equ   *-2
;
        ldy   #0
@y      equ   *-2
        stb   @b
        ldb   #1                ; move to next file id, offset of 1
        lda   direntry.bitfld,y
        lsla
        adcb  #0                ; add one offset if file is compressed 
        lsla
        adcb  #0                ; add one offset if file is dynamically linked
        abx                     ; apply new file id
        ldb   #0
@b      equ   *-1
;
        tst   loader.scene.fileCount+1
        bne   >
        dec   loader.scene.fileCount
!       dec   loader.scene.fileCount+1
        bne   @loop
        puls  y,pc

;---------------------------------------
; loader.dir.load
;
; input  REG : [A] diskid
;---------------------------------------
; Load directory entries
;---------------------------------------

loader.dir.load
        sta   >diskid             ; Save desired directory id for later check
        ldu   >loader.dir
        beq   >
        cmpa  dirheader.diskid,u
        bne   @free
        rts                       ; Requested diskid is already loaded, return
@free   
        jsr   tlsf.free           ; Requested diskid is different, free actual directory
!
        ldd   #ptsec
        std   >loader.dir
; set default dir location on disk
        ldb   #$01                ; D: [face]
        ldx   #$0000              ; X: [track] [sector]
; read first directory sector
        lda   >diskid
        cmpa  #10                 ; This version handle the display of disk id range 0-9
        blo   @ascii
        lda   #33+128             ; Print an esclamation when disk id is over 9
        bra   >
@ascii  adda  #48+128             ; Base index for ascii numbers plus end string bit flag
!       sta   >messdiskid         ; Update message string with id
        stb   <map.DK.DRV         ; Set directory location
        tfr   x,d                 ; on floppy disk
        sta   <map.DK.TRK+1       ; B is loaded with sector id
        ldy   >loader.dir         ; Loading address for
        sty   <map.DK.BUF         ; directory data
        lda   #$02                ; Read code
        sta   <map.DK.OPC         ; operation
        ldu   #sclist             ; Interleave list
        ldx   #messIO             ; Info message
        lda   b,u                 ; Get sector
        sta   <map.DK.SEC         ; number
@retry  jsr   >map.DKCONT         ; Load sector
        bcc   >                   ; Skip if no error
        jsr   >map.DKCONT         ; Reload sector
        bcc   >                   ; Skip if no error
@info   jsr   >info               ; Error
        bra   @retry
; check for directory tag match
!       ldx   #messinsertdisk
        lda   dirheader.tag,y
        cmpa  #'I'
        bne   @info
        lda   dirheader.tag+1,y
        cmpa  #'D'
        bne   @info
        lda   dirheader.tag+2,y
        cmpa  #'X'
        bne   @info
; check for directory id match
        lda   dirheader.diskid,y
        cmpa  >diskid
        bne   @info
; read remaining directory entries
        lda   dirheader.nsector,y ; init nb sectors to read      
        sta   >nsect
; allocate memory
        stb   @b
        clrb
        jsr   tlsf.malloc
        stu   >loader.dir
        leay  256,u               ; First sector will be copied later
        ldb   #0
@b      equ   *-1
        ldu   #sclist
        ldx   #messIO             ; Error message
        bra   @next
@load   lda   b,u                 ; Get sector
        sta   <map.DK.SEC         ; number
        jsr   >map.DKCONT         ; Load sector
        bcc   @next               ; Skip if no error
        jsr   >map.DKCONT         ; Reload sector
        bcc   @next               ; Skip if no error
        jmp   err                 ; Error
@next   inc   <map.DK.BUF         ; Move sector ptr
        incb                      ; Sector+1
        dec   >nsect              ; Next
        bne   @load               ; sector
; copy first sector into allocated memory
        lda   #128
        ldx   #ptsec
        ldy   loader.dir
!       ldu   ,x++               ; Read data
        stu   ,y++               ; Write data
        deca                     ; Until last
        bne   <                  ; data reached
        rts


;---------------------------------------
; loader.file.load
;
; input  REG : [X] file number
; input  REG : [B] destination - page number
; input  REG : [U] destination - address
;
; output REG : [D] $ff00 = empty file
;---------------------------------------
; Load a file from disk to RAM
; by file id
;---------------------------------------
loader.file.load
        pshs  dp,d,x,y,u
        jsr   switchpage
* Prepare loading
        jsr   loader.dir.getFile
        ldd   direntry.sizea,y   ; check empty file flag
        cmpd  #$ff00
        bne   >
        rts                      ; file is empty, exit
!       ldb   direntry.bitfld,y  ; test if compressed data
        bpl   >                  ; skip if not compressed
        ldd   direntry.coffset,y ; get offset to write data
        leau  d,u
        bra   >

;---------------------------------------
; loader.file.loadByDir
;
; input  REG : [Y] ptr to file directory
; input  REG : [B] destination - page number
; input  REG : [U] destination - address
;---------------------------------------
; Load a file from disk to RAM
; by ptr to file directory
;---------------------------------------
loader.file.loadByDir
        pshs  dp,d,x,y,u
!       lda   #$60
        tfr   a,dp               ; Set DP
        ldb   direntry.nsector,y ; Get number of sectors
        stb   >nsect             ; Set sector count
        ldd   direntry.track,y   ; Set track, face and
        std   >track             ; sector number
* First sector
        ldb   direntry.sizea,y   ; Skip if
        beq   ld3                ; full sect
        ldx   #ptsec             ; Init buffer
        stx   <map.DK.BUF        ; location
        bsr   ldsec              ; Load sector
        ldd   direntry.sizea,y   ; Read A:size, B:offset
        abx                      ; Adjust data ptr
        bsr   tfrxua             ; Copy data from buffer to RAM
* Intermediate sectors
ld3     stu   <map.DK.BUF        ; Init dest location
ld4     ldb   >nsect             ; Exit if
        beq   ld7                ; no sector
        cmpb  #1
        bhi   ld5                ; Exit if
        lda   direntry.sizez,y   ; last sector
        bne   ld6
ld5     bsr   ldsec              ; Load sector
        inc   <map.DK.BUF        ; Update dest location MSB
        bra   ld4                ; Next sector
* Last sector
ld6     ldb   >nsect             ; Skip if
        beq   ld7                ; no last sector
        ldu   <map.DK.BUF        ; Data pointer
        ldx   #ptsec             ; Init buffer
        stx   <map.DK.BUF        ; location
        bsr   ldsec              ; Load sector
        lda   direntry.sizez,y   ; Copy
        bsr   tfrxua             ; data
* Exit
ld7     clra                     ; file is not empty
        puls  dp,d,x,y,u,pc

* Copy memory space
tfrxua
        ldb   ,x+                ; Read data
        stb   ,u+                ; Write data
        deca                     ; Until las
        bne   tfrxua             ; data reached
return  rts

* Load a sector
ldsec   equ   *
        pshs  x,y,u
        lda   >track             ; [0000 000] track [0] drive
        lsr   <map.DK.DRV        ; make room to drive id
        lsra                     ; set cc with bit0 (drive) of track variable
        rol   <map.DK.DRV        ; set bit0 of drive id with cc
        ldb   >track
        andb  #$06               ; get skew based on track nb : 0, 2, 4, 6, 0, 2, 4, 6, ...
        addb  >sector            ; add sector to skew
        andb  #$0f               ; loop the index
        ldx   #sclist            ; interleave table
        ldb   b,x                ; read sector number
        clr   <map.DK.TRK        ; init track msb (always 0)
        std   <map.DK.TRK+1      ; track/sector
        jsr   >map.DKCONT        ; load sector
        bcc   ldsec1             ; skip if ok
        jsr   >map.DKCONT        ; reload sector
        lbcs  error              ; I/O Error
* Next sector
ldsec1  ldd   >track             ; read track/sect
        addd  #$f1               ; inc sector, move to next face and move to next track
        andb  #$0f               ; keep only sector bits
        std   >track             ; save track/face/sector
        dec   >nsect             ; counter-1
* Update load bar
        jsr   >pulse             ; send sector pulse
        puls  x,y,u,pc

* Default exit if disk error
dskerr  jmp   [$fffe]

* Interleave 2 with a default disk format (interleave 7)
sclist  fcb   $01,$0f,$0d,$0b
        fcb   $09,$07,$05,$03
        fcb   $08,$06,$04,$02
        fcb   $10,$0e,$0c,$0a

;---------------------------------------
; loader.file.unload
;
;---------------------------------------
; unload a file from RAM
;---------------------------------------
loader.file.unload
        rts

;---------------------------------------
; Display messages
;
; X : [ptr to ascii string]
;---------------------------------------

* Display error message
err     ldu   #messloc           ; Location
        bsr   err2               ; Display location
        leau  ,x                 ; Message pointer
        bsr   err2               ; Display message
err0    bra   err0               ; Infinite loop

* Display message
err1    bsr   err3               ; Display char
err2    ldb   ,u+                ; Read char
        bpl   err1               ; Next if not last
        andb  #$7f               ; Mask char
err3    jmp   map.PUTC           ; Display for TO - PUTC

* Display info message and wait a keystroke
info    ldu   #messloc           ; Location
        bsr   err2               ; Display location
        leau  ,x                 ; Message pointer
        bsr   err2               ; Display message
!       jsr   map.KTST
        bcc   <
        rts

* Location message
messloc fcb   $1f,$21,$21
        fcb   $1f,$11,$13        ; 3 lines (11-13)
        fcb   $1b,$47            ; font : white
        fcb   $1b,$51            ; background : red
        fcb   $0c                ; cls
        fcb   $1f,$4c,$4b+$80    ; locate for MO

messIO         fcs   "     I/O|Error"
messinsertdisk fcs   "   Insert disk 0"
messdiskid     equ *-1


;---------------------------------------
; Switch page
;
; B: [destination - page number]
; U: [destination - address]
;---------------------------------------
switchpage
        cmpu  #$4000             ; Skip if
        blo   >                  ; cartridge space
        lda   #$10
        ora   <$6081             ; Set RAM
        sta   <$6081             ; over data
        sta   >$e7e7             ; space
        stb   >map.CF74021.DATA  ; Switch RAM page
        rts
!       orb   #$60               ; Set RAM over cartridge space
        stb   >map.CF74021.CART  ; Switch RAM page
        rts


;---------------------------------------
; loader.dir.getFile
;
; input  REG : [X] file id
; output REG : [Y] ptr to file direntry
;---------------------------------------
; Get file directory entry
;
; TODO : scale the file id in the builder,
;        and saves a lot of instructions here
;---------------------------------------
loader.dir.getFile
        ldy   >loader.dir
        leay  sizeof{dirheader},y 
        tfr   x,d
        _lsld      ; Scale file id
        _lsld      ; to dir entry size
        _lsld
        leay  d,y  ; Y ptr to file direntry
        rts


;---------------------------------------
; loader.file.decompress
;
; input  REG : [X] file number
; input  REG : [B] destination - page number
; input  REG : [U] destination - address
;---------------------------------------
; uncompress a file by using zx0
;---------------------------------------
loader.file.decompress
        pshs  d,x,y,u
        jsr   switchpage
        jsr   loader.dir.getFile
        ldb   direntry.bitfld,y  ; test if compression flag
        bpl   @rts               ; no, exit
        ldd   direntry.coffset,y ; get offset to write data
        leax  d,u                ; set x to start of compressed data
        pshs  y
        jsr   >zx0_decompress    ; decompress and set u to end of decompressed data
        puls  y
        lda   #6                 ; copy last 6 bytes
        leax  direntry.cdataz,y  ; set read ptr
        jsr   tfrxua
@rts    puls  d,x,y,u,pc

 INCLUDE "new-engine/compression/zx0/zx0_6809_mega.asm"
 SETDP $ff


;---------------------------------------
; loader.file.link
;
; input  REG : [X] file number
; input  REG : [B] destination - page number
; input  REG : [U] destination - address
;---------------------------------------
; load time link using lwasm simplified
; obj data (not all link features are
; implemented)
;---------------------------------------
loader.file.link
        pshs  d,x,y,u
        jsr   loader.dir.getFile
        ldb   direntry.bitfld,y  ; test if load time link flag
        cmpb  #%01000000
        beq   @rts               ; no, exit
;
        ; load link data for a file
        ldd   direntry.lsize,y  ; Read file data size
        std   @y
        jsr   tlsf.malloc
        ldy   #0
@y      equ   *-2
;
        ldb   direntry.bitfld,y  ; test if compression flag
        bpl   >
        leay  8,y                ; skip compression block
!       leay  8,y                ; skip file block
        ldb   #loader.PAGE
        jsr   loader.file.loadByDir
;
        ; [u] is linkmeta
; store ...
        ldx   2,s                ; load file id
        ldb   1,s                ; load file dest page
        ldu   6,s                ; load file dest addr
; store ...
        ldu   >loader.dir
        lda   dirheader.diskid,u ; load disk id
; store ...
;
;       TODO conserver l'état en RAM des fichiers chargés et des données de link
;       possible de le gérer avec le memory pool, a condition de réallouer l'espace à chaque nouveau fichier
;       eventuellement en utilisant une allocation par groupe
; ex: 
;00 0000 04 0000 0100 ; [dir:id] [file:id] [code:page] [code:address] [linkmeta:ptr in memory pool]
;00 0000 04 123C 0200 ; [dir:id] [file:id] [code:page] [code:address] [linkmeta:ptr in memory pool]
;00 0000 05 2F10 0300 ; [dir:id] [file:id] [code:page] [code:address] [linkmeta:ptr in memory pool]
;
@rts    puls  d,x,y,u,pc

; file link data :
;
;		- export absolute           ; export a 16 bit constant (will be processed as a 8 or 16 bits extern when applying value)
; 
;		03 0100 :    0002           ; [nb of elements]
;		             0047 0003      ; key of symbol, value of symbol
;		             0048 0004      ; key of symbol, value of symbol
;
;       - export relative           ; export a 16 bit relative constant (will be processed as a 8 or 16 bits extern when applying value)
;
;		03 0106 :    0001           ; [nb of elements]
;		             0059 0586      ; key of symbol, value of symbol (should add section base address to this value before applying)
;		             
;		- intern                    ; relocation of local variables
;		            
;		03 010A :    0001           ; [nb of elements]
;		             0162 00C3      ; [offset to write location] [PLUS operand] - example : intern ( I16=195 IS=\02code OP=PLUS ) @ 0162
;
;		- extern (8bit)             ; link to extern 8 bit variables
;		             
;		03 0122 :    0001           ; [nb of elements]
;		             0014 0000 0001 ; [offset to write location] [PLUS operand] [symbol id] - example : extern 8bit ( FLAGS=01 ES=ymm.NO_LOOP ) @ 0014
;
;		- extern (16bit)            ; link to extern 16 bit variables
;		             
;		03 0110 :    0002           ; [nb of elements]
;		             0001 FFF4 0002 ; [offset to write location] [PLUS operand] [symbol id] - example : extern ( I16=-12 ES=Obj_Index_Address OP=PLUS ) @ 0001
;		             003E 0000 0003 ;  

loader.memoryPool equ *
