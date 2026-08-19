;*******************************************************************************
; La musique SN76489 du title — les données seules
;
; Le lecteur VGC n'est PAS résident (le title est son premier consommateur
; v2 ; côté stage il reste débranché, la décision est découplée — voir le
; plan de portage). Il est chargé par la scène du title dans l'arène title,
; et ce fichier est assemblé DANS LE MÊME direntry que lui
; (title.sound.vgc) : un direntry tient sur une page, la colocalisation
; lecteur+données est donc structurelle — le lecteur ne monte qu'une page
; sous IRQ.
;
; Dialecte v2 (docs/lang/en/migration/kept-v2-api.md) : le symbole nomme les
; données, la table Snd_index de la v1 (music/vgc.asm, gardé en référence)
; disparaît.
;*******************************************************************************

sounds.title.vgc EXPORT

 SECTION code

sounds.title.vgc
        INCLUDEBIN "src/title/music/adnz/vgc/music.vgc"

 ENDSECTION
