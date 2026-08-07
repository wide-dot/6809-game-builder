 IFNDEF loader.PAGE
loader.PAGE equ 4
 ENDC

 IFNDEF loader.ADDRESS
loader.ADDRESS equ $A000
 ENDC

* V2-DEVIATION : le pool remplit par defaut la DEMI-page du loader, plus la
* page entiere. Le TO8 echange les deux moities de 8 Ko vues par la fenetre
* cartouche : melanger dans une meme moitie du code atteint par $A000 (le
* loader) et du contenu atteint par $0000 est un piege — la regle est une
* moitie entiere au loader et son pool, l'autre au reste. Le pool monte donc
* jusqu'a la frontiere de demi-page, ni plus ni moins.
 IFNDEF loader.DEFAULT_DYNAMIC_MEMORY_SIZE
loader.DEFAULT_DYNAMIC_MEMORY_SIZE equ loader.ADDRESS-loader.memoryPool+$2000
 ENDC

 IFNDEF loader.DEFAULT_SCENE_DIR_ID
loader.DEFAULT_SCENE_DIR_ID equ 0
 ENDC

 IFNDEF loader.DEFAULT_SCENE_FILE_ID
loader.DEFAULT_SCENE_FILE_ID equ 0
 ENDC

 IFNDEF loader.DEFAULT_SCENE_EXEC_PAGE
loader.DEFAULT_SCENE_EXEC_PAGE equ 5
 ENDC

 IFNDEF loader.DEFAULT_SCENE_EXEC_ADDR
loader.DEFAULT_SCENE_EXEC_ADDR equ $6100
 ENDC