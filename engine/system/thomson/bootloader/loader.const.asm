; Jump table equates for loader functions
; --------------------------------------
loader.scene.loadDefault.IDX    equ   0  ; Load and run the default scene at boot time
loader.scene.load.IDX           equ   3  ; Load a scene by file id
loader.scene.apply.IDX          equ   6  ; Apply a scene by loading files to RAM
loader.dir.load.IDX             equ   9  ; Load directory entries
loader.file.load.IDX            equ   12 ; Load a file from disk to RAM by file id
loader.file.malloc.IDX          equ   15 ; Allocate memory for a file
loader.file.decompress.IDX      equ   18 ; Uncompress a file using zx0
loader.file.linkData.load.IDX   equ   21 ; Add load time link data to RAM for a specified file
loader.file.linkData.unload.IDX equ   24 ; Remove load time link data from RAM for a specified file
loader.file.getPageID.IDX       equ   27 ; Get the page ID where a file is loaded
loader.file.linkData.count.IDX  equ   30 ; Get the number of files in the link data index
; L'entree s'AJOUTE en fin de table : les decalages precedents sont l'ABI que
; le jeu compile en dur, ils ne bougent jamais.
loader.scene.unload.IDX         equ   33 ; Remove from the index every file a scene loaded
loader.composition.load.IDX     equ   36 ; Converge RAM to a declared state (X = its table)
loader.composition.set.IDX      equ   39 ; Declare the resident state without loading (X = its table, 0 = nothing)
loader.progress.hook.set.IDX    equ   42 ; Install a progress hook (X = routine, 0 = none) and reset the counters
loader.dir.unload.IDX           equ   45 ; Give the current directory's buffer back to the pool (no-op if none)
loader.loadbar.set.IDX          equ   48 ; Install the loader's own loading bar (X = loadbar.PARAMS bytes : video page, address x+40*y, width in pixels, height, pixel byte, pulse palette entry, pulse period in units or 0, colour count, colour table) and reset the counters
; The progress hook : called by the loader after every addition to its
; progress counter — one unit per sector read (a re-read served from the
; cache counts too, the directory counts it), one per 512 bytes a compressed
; file expands to. On entry B = the units just added, X = the counters
; (word done, word total — total is what the directory says the arriving
; scenes cost, counted by the builder, added before a scene loads and before
; a composition's first read). Registers are free,
; DP is the loader's ($60 inside disk reads, $9F elsewhere : extended
; addressing only), the stack is the loader's. Budget : a hook runs between
; two sectors, in the one sector time the interleave leaves ; spend more
; than ~2 000 cycles and every sector costs a disk revolution.
