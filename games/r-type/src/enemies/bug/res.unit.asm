;*******************************************************************************
; bug — les boites de collision du gestionnaire de chaines, en unite d'ARENE
; (le motif de outslay/res.unit.asm). La passe de collision du moteur suit
; ses listes sans monter de page : les boites DOIVENT etre residentes. Membre
; des arenes stageN.res des stages qui listent le bug (1, 4, 7) — un
; fournisseur par stage, les references de lib.bug sont re-liees a chaque
; scene. Charge en zeros : prev/next arrivent propres.
;
; Deux rangees, une par INSTANCE du gestionnaire (mgr.asm) : la longue (40
; records) et la courte (12).
;*******************************************************************************

bug.boxesL EXPORT
bug.boxesS EXPORT

 SECTION code

bug.boxesL      fill  0,40*9
bug.boxesS      fill  0,12*9

 ENDSECTION
