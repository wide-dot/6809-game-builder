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
