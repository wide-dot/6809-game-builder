;*******************************************************************************
;* WAIT-EXAMPLE.ASM - Exemple d'utilisation des routines de temporisation
;* 
;* Ce fichier montre comment utiliser les routines de temporisation précise
;* pour le 6809 avec différentes fréquences d'horloge
;*******************************************************************************

        include "engine/timing/wait.asm"
        include "engine/timing/wait.macro.asm"

;*******************************************************************************
;* Point d'entrée principal
;*******************************************************************************
main
        ; Configuration de l'horloge (à adapter selon votre système)
        _wait.setClock #0              ; Configurer pour 1MHz
        ; ou
        ; _wait.setClock #1              ; Configurer pour 3.579545MHz
        
        ; Exemples d'utilisation des routines de temporisation
        
        ; 1. Temporisation en millisecondes
        _wait.ms #100                  ; Attendre 100ms
        _wait.ms #50                   ; Attendre 50ms
        _wait.ms #1000                 ; Attendre 1 seconde
        
        ; 2. Temporisation en microsecondes
        _wait.us #50                   ; Attendre 50µs
        _wait.us #100                  ; Attendre 100µs
        
        ; 3. Temporisation en cycles (précision maximale)
        _wait.cycles #1000             ; Attendre 1000 cycles
        _wait.cycles #3579             ; Attendre 3579 cycles (1ms à 3.579545MHz)
        
        ; 4. Temporisation en frames (50Hz)
        _wait.frames #2                ; Attendre 2 frames (40ms)
        _wait.frames #5                ; Attendre 5 frames (100ms)
        
        ; 5. Temporisation précise en cycles (inline)
        _wait.cycles.inline #17        ; Attendre exactement 17 cycles
        _wait.cycles.inline #100       ; Attendre exactement 100 cycles
        
        ; 6. Utilisation avec des variables
        ldb     #200                   ; Charger 200ms dans B
        bsr     wait.ms                ; Appeler directement la routine
        
        ; 7. Exemple de boucle avec temporisation
        ldb     #10                    ; 10 itérations
@loop
        ; Code à exécuter ici
        nop                             ; Simulation d'un traitement
        
        _wait.ms #100                  ; Attendre 100ms entre chaque itération
        
        decb                            ; Décrémenter le compteur
        bne     @loop                  ; Si non nul, continuer la boucle
        
        ; 8. Exemple de temporisation pour différents types d'horloge
        ; Détection automatique de la fréquence
        _wait.ms.auto #100             ; Attendre 100ms (détection auto)
        
        rts

;*******************************************************************************
;* Exemple de routine avec temporisation précise
;*******************************************************************************
example.precise.timing
        ; Cette routine montre comment obtenir une temporisation très précise
        ; en utilisant les calculs de cycles
        
        ; Pour 1MHz: 1ms = 1000 cycles
        ; Pour 3.579545MHz: 1ms = 3579 cycles
        
        ; Temporisation de 5ms à 1MHz
        ldx     #5000                  ; 5ms × 1000 cycles = 5000 cycles
        bsr     wait.cycles
        
        ; Temporisation de 5ms à 3.579545MHz
        ldx     #17895                 ; 5ms × 3579 cycles = 17895 cycles
        bsr     wait.cycles
        
        rts

;*******************************************************************************
;* Exemple de routine de clignotement LED
;*******************************************************************************
example.led.blink
        ; Exemple pratique: faire clignoter une LED
        ; avec des temporisations précises
        
        ldb     #5                     ; 5 clignotements
@blinkLoop
        ; Allumer la LED
        lda     #$FF                   ; Valeur pour allumer
        sta     led.port               ; Écrire sur le port LED
        
        _wait.ms #500                  ; Attendre 500ms (LED allumée)
        
        ; Éteindre la LED
        lda     #$00                   ; Valeur pour éteindre
        sta     led.port               ; Écrire sur le port LED
        
        _wait.ms #500                  ; Attendre 500ms (LED éteinte)
        
        decb                            ; Décrémenter le compteur
        bne     @blinkLoop             ; Si non nul, continuer
        
        rts

;*******************************************************************************
;* Variables et constantes
;*******************************************************************************
led.port       equ     $E7C0           ; Adresse du port LED (exemple)

;*******************************************************************************
;* Table de conversion pour différentes fréquences
;* 
;* Cette table peut être utilisée pour des calculs rapides
;*******************************************************************************
timing.table
        ; Cycles par milliseconde pour différentes fréquences
        fdb     1000                    ; 1MHz
        fdb     3579                    ; 3.579545MHz
        fdb     2000                    ; 2MHz (si applicable)
        fdb     4000                    ; 4MHz (si applicable)

;*******************************************************************************
;* Routine de calcul automatique de cycles
;* Entrée: A = fréquence en MHz (1, 2, 3, 4, etc.)
;* Sortie: X = cycles par milliseconde
;*******************************************************************************
calculate.cycles.per.ms
        ; Cette routine calcule automatiquement les cycles par milliseconde
        ; selon la fréquence fournie
        
        ; A contient la fréquence en MHz
        ; Cycles par ms = fréquence × 1000
        
        ldx     #1000                  ; Multiplicateur de base
        mul                             ; D × 1000 = cycles par ms
        tfr     d,x                     ; Transférer le résultat dans X
        
        rts 