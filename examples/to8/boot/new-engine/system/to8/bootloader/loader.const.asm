 IFNDEF loader.PAGE
loader.PAGE equ 4
 ENDC

 IFNDEF loader.ADDRESS
loader.ADDRESS equ 0
 ENDC

 IFNDEF loader.DEFAULT_DYNAMIC_MEMORY_SIZE
loader.DEFAULT_DYNAMIC_MEMORY_SIZE equ loader.ADDRESS-loader.dynamicMemory+$4000
 ENDC

 IFNDEF loader.DEFAULT_SCENE_DIR_ID
loader.DEFAULT_SCENE_DIR_ID equ 0
 ENDC

 IFNDEF loader.DEFAULT_SCENE_FILE_ID
loader.DEFAULT_SCENE_FILE_ID equ 0
 ENDC

 IFNDEF loader.DEFAULT_SCENE_ENTRY_POINT
loader.DEFAULT_SCENE_ENTRY_POINT equ $6100
 ENDC