;*******************************************************************************
; La musique YM2413 du stage 6 — les données seules
;
; Le niveau 6 n'a de musique ni en v1 ni en v2 (aucun dossier music dans son
; niveau v1) : ce bloc rejoue les OCTETS du niveau 1 en attendant un choix
; de l'auteur (candidats au TODO : le theme.ymm partagé des dossiers 04/07,
; ou une conversion vgm2ymm dédiée).
;
; Le nom est celui de CE stage : réutiliser `sounds.level1.ymm` ici en
; ferait un export multi-fournisseurs — le bloc du stage 1 redeviendrait un
; fichier indexé du pool, la fragilité exacte du game over (leçon du
; chantier collision). Un fournisseur par nom, même quand les octets sont
; les mêmes.
;*******************************************************************************

sounds.level6.ymm     EXPORT

 SECTION code

sounds.level6.ymm
        INCLUDEBIN "src/stages/01/music/adnz/ymm/music.ymm"

 ENDSECTION
