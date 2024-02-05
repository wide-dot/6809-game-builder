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
; - réfléchir aux points suivants :
;   - gérer le fait qu'on puisse charger plusieurs instances d'un meme fichier à deux endroits différents en RAM, comment identifier celui qu'on "remove" dans le linkdata ? => addr en param in
;
;*******************************************************************************
 SETDP $ff ; prevents lwasm from using direct address mode
        INCLUDE "new-engine/global/glb.const.asm"
        INCLUDE "new-engine/6809/macros.asm"
        INCLUDE "new-engine/6809/types.const.asm"
        INCLUDE "new-engine/system/to8/map.const.asm"
        INCLUDE "new-engine/system/to8/bootloader/loader.const.asm"

; directory structure
; -------------------
dir.header STRUCT
tag     rmb types.BYTE*3 ; [I] [D] [X]
diskId  rmb types.BYTE   ; [0000 0000]              - [disk id 0-255]
nsector rmb types.BYTE   ; [0000 0000]              - [nb of sectors for direntries]
        ENDSTRUCT

; dir.entry main structure
; -----------------------
dir.entry STRUCT
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

; dir.entry compress structure
; ---------------------------
coffset  rmb types.WORD   ; [0000 0000] [0000 0000] - [offset to compressed data]
cdataz   rmb types.BYTE*6 ; [0000 0000]             - [last 6 bytes of uncompressed file data]

; dir.entry linker structure
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

        org   loader.ADDRESS
        jmp   >loader.scene.loadDefault    ; OK
        jmp   >loader.scene.load           ; OK
        jmp   >loader.scene.apply          ; OK
        jmp   >loader.dir.load             ; OK
        jmp   >loader.file.load            ; OK
        jmp   >loader.file.malloc          ; OK
        jmp   >loader.file.decompress      ; OK
        jmp   >loader.file.linkData.load   ; OK
        jmp   >loader.file.linkData.unload ; TODO

; callbacks that can be modified by user at runtime
error   jmp   >dskerr     ; Called if a read error is detected
pulse   jmp   >return     ; Called after each sector read (ex. for progress bar)

; temporary space
; ---------------
ptsec  fill  0,256 ; Temporary space for partial sector loading
diskId fcb   0     ; Disk id
nsect  fcb   0     ; Sector counter
track  fcb   0     ; Track number
sector fcb   0     ; Sector number

; globals
; --------------
loader.dir              fdb   0 ; file directory
loader.file.linkDataIdx fdb   0 ; link data index of loaded files
loader.scene.routine    fdb   0
loader.scene.fileCount  fdb   0
linkData.currentFile    fdb   0
linkData.currentSymbol  fdb   0

; memory utils
; --------------
        INCLUDE   "new-engine/memory/malloc/tlsf.asm"
        INCLUDE   "new-engine/memory/malloc/tlsf-realloc.asm"
        INCLUDE   "new-engine/memory/memcpy/memcpy.asm"

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

        ; load default scene file
        ldx   #loader.DEFAULT_SCENE_FILE_ID
        jsr   loader.scene.load

        ldb   #loader.DEFAULT_SCENE_EXEC_PAGE
        ldu   #loader.DEFAULT_SCENE_EXEC_ADDR
        jsr   switchpage
        jmp   loader.DEFAULT_SCENE_EXEC_ADDR


;-----------------------------------------------------------------
; loader.scene.load
;
; input  REG : [X] scene file id
;
;-----------------------------------------------------------------
; Load a scene
;-----------------------------------------------------------------
loader.scene.load

        ; load default scene file
        jsr   loader.file.malloc
        cmpu  #0
        bne   >
        rts
!
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

        ldx   #loader.file.linkData.load
        stx   loader.scene.routine
        jsr   loader.scene.apply

        ; once all files are loaded, proceed to the link
        jsr   loader.file.link

        ; free memory for default scene file
        jsr   tlsf.free
        rts


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

        ldd   dir.entry.sizea,y  ; Check for empty file flag
        cmpd  #$ff00
        bne   >
        ldu   #0                ; If file is empty, return 0
        puls  x,pc
!
        ldd   dir.entry.sizeu,y  ; Read file data size
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
        ldd   dir.entry.sizeu,y   ; Read file data size
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
        ldd   dir.entry.sizeu,y   ; Read file data size
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
        lda   dir.entry.bitfld,y
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
; input  REG : [A] diskId
;---------------------------------------
; Load directory entries
;---------------------------------------
loader.dir.load
        sta   >diskId             ; Save desired directory id for later check
        ldu   >loader.dir
        beq   >
        cmpa  dir.header.diskId,u
        bne   @free
        rts                       ; Requested diskId is already loaded, return
@free   
        jsr   tlsf.free           ; Requested diskId is different, free actual directory
!
        ldd   #ptsec
        std   >loader.dir
; set default dir location on disk
        ldb   #$01                ; D: [face]
        ldx   #$0000              ; X: [track] [sector]
; read first directory sector
        lda   >diskId
        cmpa  #10                 ; This version handle the display of disk id range 0-9
        blo   @ascii
        lda   #33+128             ; Print an esclamation when disk id is over 9
        bra   >
@ascii  adda  #48+128             ; Base index for ascii numbers plus end string bit flag
!       sta   >messdiskId         ; Update message string with id
        stb   <map.DK.DRV         ; Set directory location
        tfr   x,d                 ; on floppy disk
        sta   <map.DK.TRK+1       ; B is loaded with sector id
        ldy   >loader.dir    ; Loading address for
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
        lda   dir.header.tag,y
        cmpa  #'I'
        bne   @info
        lda   dir.header.tag+1,y
        cmpa  #'D'
        bne   @info
        lda   dir.header.tag+2,y
        cmpa  #'X'
        bne   @info
; check for directory id match
        lda   dir.header.diskId,y
        cmpa  >diskId
        bne   @info
; read remaining directory entries
        lda   dir.header.nsector,y ; init nb sectors to read      
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
; input  REG : [X] file id
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
        ldd   dir.entry.sizea,y   ; check empty file flag
        cmpd  #$ff00
        bne   >
        puls  dp,d,x,y,u,pc       ; file is empty, exit
!       ldb   dir.entry.bitfld,y  ; test if compressed data
        bpl   >                   ; skip if not compressed
        ldd   dir.entry.coffset,y ; get offset to write data
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
!       lda   #map.REG.DP
        tfr   a,dp                ; Set DP
        ldb   dir.entry.nsector,y ; Get number of sectors
        stb   >nsect              ; Set sector count
        ldd   dir.entry.track,y   ; Set track, face and
        std   >track              ; sector number
* First sector
        ldb   dir.entry.sizea,y   ; Skip if
        beq   ld3                 ; full sect
        ldx   #ptsec              ; Init buffer
        stx   <map.DK.BUF         ; location
        bsr   ldsec               ; Load sector
        ldd   dir.entry.sizea,y   ; Read A:size, B:offset
        abx                       ; Adjust data ptr
        bsr   tfrxua              ; Copy data from buffer to RAM
* Intermediate sectors
ld3     stu   <map.DK.BUF         ; Init dest location
ld4     ldb   >nsect              ; Exit if
        beq   ld7                 ; no sector
        cmpb  #1
        bhi   ld5                 ; Exit if
        lda   dir.entry.sizez,y   ; last sector
        bne   ld6
ld5     bsr   ldsec               ; Load sector
        inc   <map.DK.BUF         ; Update dest location MSB
        bra   ld4                 ; Next sector
* Last sector
ld6     ldb   >nsect              ; Skip if
        beq   ld7                 ; no last sector
        ldu   <map.DK.BUF         ; Data pointer
        ldx   #ptsec              ; Init buffer
        stx   <map.DK.BUF         ; location
        bsr   ldsec               ; Load sector
        lda   dir.entry.sizez,y   ; Copy
        bsr   tfrxua              ; data
* Exit
ld7     clra                      ; file is not empty
        puls  dp,d,x,y,u,pc

* Copy memory space
tfrxua
        ldb   ,x+                 ; Read data
        stb   ,u+                 ; Write data
        deca                      ; Until las
        bne   tfrxua              ; data reached
return  rts

* Load a sector
ldsec   equ   *
        pshs  x,y,u
        lda   >track              ; [0000 000] track [0] drive
        lsr   <map.DK.DRV         ; make room to drive id
        lsra                      ; set cc with bit0 (drive) of track variable
        rol   <map.DK.DRV         ; set bit0 of drive id with cc
        ldb   >track
        andb  #$06                ; get skew based on track nb : 0, 2, 4, 6, 0, 2, 4, 6, ...
        addb  >sector             ; add sector to skew
        andb  #$0f                ; loop the index
        ldx   #sclist             ; interleave table
        ldb   b,x                 ; read sector number
        clr   <map.DK.TRK         ; init track msb (always 0)
        std   <map.DK.TRK+1       ; track/sector
        jsr   >map.DKCONT         ; load sector
        bcc   ldsec1              ; skip if ok
        jsr   >map.DKCONT         ; reload sector
        lbcs  error               ; I/O Error
* Next sector
ldsec1  ldd   >track              ; read track/sect
        addd  #$f1                ; inc sector, move to next face and move to next track
        andb  #$0f                ; keep only sector bits
        std   >track              ; save track/face/sector
        dec   >nsect              ; counter-1
* Update load bar
        jsr   >pulse              ; send sector pulse
        puls  x,y,u,pc

* Default exit if disk error
dskerr  jmp   [$fffe]

* Interleave 2 with a default disk format (interleave 7)
sclist  fcb   $01,$0f,$0d,$0b
        fcb   $09,$07,$05,$03
        fcb   $08,$06,$04,$02
        fcb   $10,$0e,$0c,$0a


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
messdiskId     equ *-1


;---------------------------------------
; Switch page
;
; B: [destination - page number]
; U: [destination - address]
;---------------------------------------
switchpage
        cmpu  #$A000             ; Skip if not data space
        blo   >
        lda   #$10
        ora   <$6081             ; Set RAM
        sta   <$6081             ; over data
        sta   >$e7e7             ; space
        stb   >map.CF74021.DATA  ; Switch RAM page
        rts
!
        cmpu  #$6000             ; Skip if not resident space
        blo   >
        rts                      ; nothing to do ... it's resident memory
!
        cmpu  #$4000             ; Skip if not video space
        blo   >
        andb  #$01               ; Keep only half page A or B
        orb   $E7C3              ; Merge register value
        stb   $E7C3              ; Set desired half page in video space
        rts
!
        cmpu  #$E000             ; Skip if not valid address 
        bhs   >
        orb   #$60               ; Set RAM over cartridge space
        stb   >map.CF74021.CART  ; Switch RAM page
        rts
!       bra   *                  ; error trap


;---------------------------------------
; loader.dir.getFile
;
; input  REG : [X] file id
; output REG : [Y] ptr to file dir.entry
;---------------------------------------
; Get file directory entry
;
; TODO : scale the file id in the builder,
;        and saves a lot of instructions here
;---------------------------------------
loader.dir.getFile
        ldy   >loader.dir
        leay  sizeof{dir.header},y 
        tfr   x,d
        _lsld      ; Scale file id
        _lsld      ; to dir entry size
        _lsld
        leay  d,y  ; Y ptr to file dir.entry
        rts


;---------------------------------------
; loader.file.decompress
;
; input  REG : [X] file id
; input  REG : [B] destination - page number
; input  REG : [U] destination - address
;---------------------------------------
; uncompress a file by using zx0
;---------------------------------------
loader.file.decompress
        pshs  d,x,y,u
        jsr   switchpage
        jsr   loader.dir.getFile
        ldb   dir.entry.bitfld,y  ; test if compression flag
        bpl   @rts               ; no, exit
        ldd   dir.entry.coffset,y ; get offset to write data
        leax  d,u                ; set x to start of compressed data
        pshs  y
        jsr   >zx0_decompress    ; decompress and set u to end of decompressed data
        puls  y
        lda   #6                 ; copy last 6 bytes
        leax  dir.entry.cdataz,y  ; set read ptr
        jsr   tfrxua
@rts    puls  d,x,y,u,pc

 INCLUDE "new-engine/compression/zx0/zx0_6809_mega.asm"
 SETDP $ff


;---------------------------------------
; loader.file.linkData.load
;
; input  REG : [X] file id
; input  REG : [B] destination - page number
; input  REG : [U] destination - address
;---------------------------------------
; add load time link data to RAM
; for a specified file
;---------------------------------------

; linkDataIdx structure
; -------------------
linkData.header STRUCT
totalSlots    rmb types.WORD ; [0000 0000] [0000 0000] - [nb of total slots]
occupiedSlots rmb types.WORD ; [0000 0000] [0000 0000] - [nb of occupied slots]
        ENDSTRUCT

linkData.entry STRUCT
diskId   rmb types.BYTE   ; [0000 0000]              - [disk id]
fileId   rmb types.WORD   ; [0000 0000] [0000 0000]  - [file id]
filePage rmb types.BYTE   ; [0000 0000]              - [file data page location]
fileAddr rmb types.WORD   ; [0000 0000] [0000 0000]  - [file data address location]
linkData rmb types.WORD   ; [0000 0000] [0000 0000]  - [ptr in memory pool to link data]
        ENDSTRUCT

loader.file.linkData.POOL_QTY equ 8

loader.file.linkData.load
        pshs  d,x,y,u
        jsr   loader.dir.getFile
        ldb   dir.entry.bitfld,y              ; Test if load time link flag
        andb  #%01000000
        bne   >                               ; yes, continue
        puls  d,x,y,u,pc                      ; no, exit
!
        ; check link data size for this file, and allocate memory for loading
        ldd   dir.entry.lsize,y               ; Read file data size
        bne   >
        puls  d,x,y,u,pc                      ; Ignore empty link file
!       sty   @y
        jsr   tlsf.malloc
        stu   @linkData
        ldy   #0
@y      equ   *-2
;
        ; load link data file
        ldb   dir.entry.bitfld,y              ; test if compression flag
        bpl   >
        leay  8,y                             ; skip compression block
!       leay  8,y                             ; skip file block
        ldb   #loader.PAGE
        jsr   loader.file.loadByDir
;
        ; store file location index on RAM (data and link data)
        ldu   >loader.file.linkDataIdx
        bne   >
        ldd   #sizeof{linkData.header}+loader.file.linkData.POOL_QTY*sizeof{linkData.entry} ; a. First load of link data
        jsr   tlsf.malloc                     ; Allocate a new set of slots
        stu   >loader.file.linkDataIdx
        ldd   #loader.file.linkData.POOL_QTY
        std   linkData.header.totalSlots,u    ; init nb of allocated slots
        ldd   #1
        bra   @end
!       ldd   linkData.header.occupiedSlots,u ; b. Already loaded link data
        cmpd  linkData.header.totalSlots,u
        bhs   >                               ; Branch if no more slot available
        addd  #1                              ; c. Use a free slot
        bra   @end
!       ldd   linkData.header.totalSlots,u    ; d. All slots are in use, reallocate
        addd  #loader.file.linkData.POOL_QTY  ; add new bunch of blocks
        std   @d
        _asld
        _asld
        _asld                                 ; mult by struct size
        addd  #sizeof{linkData.header}        ; add header
        jsr   tlsf.realloc                    ; [d] : new size - [u] : ptr to allocated memory
        stu   >loader.file.linkDataIdx
        ldd   #0                              ; Update new block header
@d      equ   *-2
        std   linkData.header.totalSlots,u    ; Set max number of slots
        ldd   linkData.header.occupiedSlots,u
        addd  #1
@end
        std   linkData.header.occupiedSlots,u ; Set current slots in use
        subd  #1
        ; compute location of slot
        _asld
        _asld
        _asld                                 ; mult by struct size
        addd  #types.WORD*2                   ; add header
        leau  d,u                             ; u is a ptr to slot
        ldx   >loader.dir
        lda   dir.header.diskId,x             ; load disk id
        sta   linkData.entry.diskId,u
        ldd   2,s                             ; load file id
        std   linkData.entry.fileId,u
        ldb   1,s                             ; load file dest page
        stb   linkData.entry.filePage,u
        ldd   6,s                             ; load file dest addr
        std   linkData.entry.fileAddr,u 
        ldd   #0                              ; load ptr to link data
@linkData equ *-2
        std   linkData.entry.linkData,u
        ; relocate the binary
        ldy   @linkData                       ; set y as ptr to file link data
        jsr   linkData.content.exportAbs.skip ; skip export link data
        jsr   linkData.content.exportRel.skip
        ldb   1,s                             ; load file dest page
        ldu   6,s                             ; load file dest addr
        jsr   loader.file.intern.link
@rts    puls  d,x,y,u,pc


;---------------------------------------
; loader.file.linkData.unload
;
; input  REG : [B] directory id
; input  REG : [X] file id
;---------------------------------------
; remove load time link data from RAM
; for a specified file
;---------------------------------------
loader.file.linkData.unload
        ; TODO
        ; search for dir/file id in loader.file.linkData
        ; move following linkdata one slot ahead
        ; decrement nb of occupied slots
        ; reallocate if total slots - occupied slots = 8
        rts


;---------------------------------------
; loader.file.link
;
;---------------------------------------
; load time link using lwasm simplified
; obj data (not all link features are
; implemented, just a single ADD op)
;---------------------------------------

; linkData.content structures
; ---------------------------

linkData.content.header    STRUCT ; this header is ahead of each content type
size    rmb types.WORD            ; number of items
        ENDSTRUCT

linkData.content.exportAbs STRUCT ; export absolute : export a 16 bit constant (will be processed as a 8 or 16 bits extern when applying value)
key     rmb types.WORD            ; key of symbol
value   rmb types.WORD            ; value of symbol
        ENDSTRUCT

linkData.content.exportRel STRUCT ; export relative : export a 16 bit relative constant (will be processed as a 8 or 16 bits extern when applying value)
key     rmb types.WORD            ; key of symbol
value   rmb types.WORD            ; value of symbol (should add section base address of export to this value before applying)
        ENDSTRUCT

linkData.content.intern    STRUCT ; relocation of local variables - example : extern 8bit ( FLAGS=01 ES=ymm.NO_LOOP ) @ 0014
offset  rmb types.WORD            ; offset to symbol
operand rmb types.WORD            ; PLUS operand
        ENDSTRUCT

linkData.content.extern8   STRUCT ; link to extern 8 bit variables - example : intern ( I16=195 IS=\02code OP=PLUS ) @ 0162
offset  rmb types.WORD            ; offset to symbol
operand rmb types.WORD            ; PLUS operand
symbol  rmb types.WORD            ; symbol id
        ENDSTRUCT

linkData.content.extern16  STRUCT ; link to extern 16 bit variables - examples : extern ( I16=-12 ES=Obj_Index_Address OP=PLUS ) @ 0001, extern ( ES=ymm.music.processFrame ) @ 003E
offset  rmb types.WORD            ; offset to symbol
operand rmb types.WORD            ; PLUS operand
symbol  rmb types.WORD            ; symbol id
        ENDSTRUCT

loader.file.link
        pshs  d,x,y,u
        ; parse each file of loader.file.linkDataIdx
        ldx   >loader.file.linkDataIdx
        beq   @rts                            ; branch if link data has never been created
        ldd   linkData.header.occupiedSlots,x
        leax  sizeof{linkData.header},x
        std   @counter
        beq   @rts                            ; branch if link data was created, but all slots were removed
@next
        ; set RAM page to make file visible
        ldd   linkData.entry.fileId,x
        std   linkData.currentFile
        ldb   linkData.entry.filePage,x
        ldu   linkData.entry.fileAddr,x
        jsr   switchpage
        ldy   linkData.entry.linkData,x
        jsr   linkData.content.exportAbs.skip
        jsr   linkData.content.exportRel.skip
        jsr   linkData.content.intern.skip
        jsr   loader.file.extern8.link
        jsr   loader.file.extern16.link
        leax  sizeof{linkData.entry},x        ; move to next file
        ldd   #0
@counter equ *-2
        subd  #1
        std   @counter
        bne   @next                           ; check if more file to process
@rts    puls  d,x,y,u,pc


;---------------------------------------
; linkData.content.<xxx>.skip
;
; input  REG : [Y] position in link data
; output REG : [Y] position in link data
;---------------------------------------
; relocate file binary with link data
;---------------------------------------

linkData.content.exportAbs.skip
linkData.content.exportRel.skip
linkData.content.intern.skip
        ldd   linkData.content.header.size,y
        _asld
        _asld
        addd  #sizeof{linkData.content.header}
        leay  d,y
        rts


;---------------------------------------
; loader.file.intern.link
;
; input  REG : [B] destination - page number
; input  REG : [U] destination - address
; input  REG : [Y] position in link data
; output REG : [Y] position in link data
;---------------------------------------
; relocate file binary with link data
;---------------------------------------
loader.file.intern.link
        pshs  d,x,u

        ; parse all INTERN symbols
        ldd   linkData.content.header.size,y
        leay  sizeof{linkData.content.header},y
        std   @counter
        bne   >
        puls  d,x,u,pc
!
        ldb   1,s                               ; restore file page number
        jsr   switchpage
!
        ldd   linkData.content.intern.operand,y ; load plus operand
        leax  d,u                               ; add file binary location
        ldd   linkData.content.intern.offset,y  ; load offset to symbol reference
        stx   d,u                               ; update address
        leay  sizeof{linkData.content.intern},y ; move to next symbol
        ldd   #0
@counter equ *-2
        subd  #1
        std   @counter
        bne   <                                 ; check if more elements to process

        puls  d,x,u,pc


;---------------------------------------
; loader.file.extern8.link
;
; input  REG : [B] destination - page number
; input  REG : [U] destination - address
; input  REG : [Y] position in link data
; output REG : [Y] position in link data
;---------------------------------------
; resolve external 8 bits symbols
;---------------------------------------
loader.file.extern8.link
        pshs  d,x,u

        ; parse all EXTERN8 symbols
        ldd   linkData.content.header.size,y
        leay  sizeof{linkData.content.header},y
        std   @counter
        bne   >
        puls  d,x,u,pc
!
        ; find symbol by searching in all file's linkData 
        ldd   linkData.content.extern8.symbol,y
        std   linkData.currentSymbol
        jsr   linkData.symbol.search
        addd  linkData.content.extern8.operand,y ; add external symbol value to plus operand
        ldx   linkData.content.extern8.offset,y  ; load offset to symbol reference
        stx   @addr
        stb   1234,u                             ; update address
@addr   equ   *-2
        leay  sizeof{linkData.content.extern8},y ; move to next symbol
        ldd   #0
@counter equ *-2
        subd  #1
        std   @counter
        bne   <                                 ; check if more elements to process
        puls  d,x,u,pc


;---------------------------------------
; loader.file.extern16.link
;
; input  REG : [U] destination - address
; input  REG : [Y] position in link data
; output REG : [Y] position in link data
;---------------------------------------
; resolve external 16 bits symbols
;---------------------------------------
loader.file.extern16.link
        pshs  d,x,u

        ; parse all EXTERN16 symbols
        ldd   linkData.content.header.size,y
        leay  sizeof{linkData.content.header},y
        std   @counter
        bne   >
        puls  d,x,u,pc
!
        ; find symbol by searching in all file's linkData 
        ldd   linkData.content.extern16.symbol,y
        std   linkData.currentSymbol
        jsr   linkData.symbol.search
        ldx   linkData.content.extern16.operand,y ; load plus operand
        leax  d,x                                 ; add external symbol value
        ldd   linkData.content.extern16.offset,y  ; load offset to symbol reference !!! ici [d]=6125 et [u]=6100
        stx   d,u                                 ; update address
        leay  sizeof{linkData.content.extern8},y  ; move to next symbol
        ldd   #0
@counter equ *-2
        subd  #1
        std   @counter
        bne   <                                 ; check if more elements to process
        puls  d,x,u,pc


linkData.symbol.search
        pshs  y,u
        ; parse each file of loader.file.linkDataIdx
        ldx   >loader.file.linkDataIdx
        ldd   linkData.header.occupiedSlots,x
        std   @fileCounter
        leax  sizeof{linkData.header},x
@fileLoop
        ; exclude from search the current file being resolved
        ldd   linkData.entry.fileId,x
        cmpd  linkData.currentFile
        beq   @nextFile
;
        ; set RAM page to make file visible
        ldu   linkData.entry.fileAddr,x
        ldy   linkData.entry.linkData,x
;
        ; parse all absolute symbols
        ldd   linkData.content.header.size,y
        leay  sizeof{linkData.content.header},y
        std   @absSymbolCounter
        beq   @parseRelSymbol
@absSymbolLoop
        ldd   linkData.content.exportAbs.key,y
        cmpd  linkData.currentSymbol
        bne   >
        ldd   linkData.content.exportAbs.value,y ; this value is absolute
        puls  y,u,pc
!       leay  sizeof{linkData.content.intern},y  ; move to next symbol
        ldd   #0
@absSymbolCounter equ *-2
        subd  #1
        std   @absSymbolCounter
        bne   @absSymbolLoop                     ; check if more elements to process
@parseRelSymbol
        ; parse all relative symbols
        ldd   linkData.content.header.size,y
        leay  sizeof{linkData.content.header},y
        std   @relSymbolCounter
        beq   @nextFile
@relSymbolLoop
        ldd   linkData.content.exportRel.key,y
        cmpd  linkData.currentSymbol
        bne   >
        tfr   u,d                                ; get base section offset
        addd  linkData.content.exportRel.value,y ; add symbol value (relative address)
        puls  y,u,pc
!       leay  sizeof{linkData.content.intern},y  ; move to next symbol
        ldd   #0
@relSymbolCounter equ *-2
        subd  #1
        std   @relSymbolCounter
        bne   @relSymbolLoop                     ; check if more elements to process
@nextFile
        leax  sizeof{linkData.entry},x           ; move to next file
        ldd   #0
@fileCounter equ *-2
        subd  #1
        std   @fileCounter
        bne   @fileLoop                          ; check if more file to process
        bra   *                                  ; unresolved symbol

loader.memoryPool equ *
