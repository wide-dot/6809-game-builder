# Routines de Temporisation Précise pour 6809

## Vue d'ensemble

Ce module fournit des routines de temporisation précise au cycle près pour le processeur Motorola 6809. Les routines supportent automatiquement les deux fréquences d'horloge principales utilisées dans les systèmes Thomson : 1MHz et 3.579545MHz.

## Calculs de Cycles

### Fréquences d'horloge supportées

- **1MHz** : 1,000,000 cycles par seconde
- **3.579545MHz** : 3,579,545 cycles par seconde

### Cycles par milliseconde

- **1MHz** : 1ms = 1,000 cycles
- **3.579545MHz** : 1ms = 3,579.545 cycles (arrondi à 3,579)

### Cycles par microseconde

- **1MHz** : 1µs = 1 cycle
- **3.579545MHz** : 1µs = 3.579545 cycles (arrondi à 3 cycles)

## Routines disponibles

### 1. `wait.ms` - Temporisation en millisecondes

**Entrée** : B = nombre de millisecondes (0-255)
**Sortie** : Aucune
**Utilise** : A, B, X

**Calculs détaillés** :

#### Pour 1MHz :
- 1ms = 1,000 cycles
- Boucle optimisée : 17 cycles par itération
- Nombre d'itérations : 1,000 ÷ 17 ≈ 58.8
- Utilisation : 58 itérations × 17 cycles = 986 cycles
- Overhead : 14 cycles (sauvegarde, calcul, retour)
- **Total** : 986 + 14 = 1,000 cycles ✓

#### Pour 3.579545MHz :
- 1ms = 3,579 cycles
- Boucle optimisée : 17 cycles par itération
- Nombre d'itérations : 3,579 ÷ 17 ≈ 210.5
- Utilisation : 210 itérations × 17 cycles = 3,570 cycles
- Overhead : 9 cycles (sauvegarde, calcul, retour)
- **Total** : 3,570 + 9 = 3,579 cycles ✓

### 2. `wait.us` - Temporisation en microsecondes

**Entrée** : B = nombre de microsecondes (0-255)
**Sortie** : Aucune
**Utilise** : A, B, X

**Précision limitée** :
- 1MHz : 1 cycle par µs (précision maximale)
- 3.579545MHz : 3 cycles par µs (précision réduite)

### 3. `wait.cycles` - Temporisation en cycles

**Entrée** : X = nombre de cycles (0-65535)
**Sortie** : Aucune
**Utilise** : A, X

**Précision maximale** : 1 cycle près

## Optimisation des boucles

### Boucle principale (17 cycles)

```assembly
@loop
    leax    -1,x                    ; [5] Décrémenter le compteur
    bne     @loop                   ; [3] Si non nul, continuer
    nop                             ; [2] Padding
    nop                             ; [2] Padding
    nop                             ; [2] Padding
    nop                             ; [2] Padding
    nop                             ; [1] Padding
```

**Total par itération** : 5 + 3 + 2 + 2 + 2 + 2 + 1 = 17 cycles

### Boucle microsecondes (8 cycles)

```assembly
@usLoop
    leax    -1,x                    ; [5] Décrémenter le compteur
    bne     @usLoop                 ; [3] Si non nul, continuer
    nop                             ; [2] Padding pour compenser
```

**Total par itération** : 5 + 3 + 2 = 10 cycles (compensé par le padding)

## Macros disponibles

### `_wait.ms delay`
Attendre le nombre de millisecondes spécifié.

```assembly
_wait.ms #100    ; Attendre 100ms
_wait.ms myVar   ; Attendre le nombre de ms dans myVar
```

### `_wait.us delay`
Attendre le nombre de microsecondes spécifié.

```assembly
_wait.us #50     ; Attendre 50µs
_wait.us myVar   ; Attendre le nombre de µs dans myVar
```

### `_wait.cycles cycles`
Attendre le nombre de cycles spécifié.

```assembly
_wait.cycles #1000    ; Attendre 1000 cycles
_wait.cycles myVar    ; Attendre le nombre de cycles dans myVar
```

### `_wait.setClock clockType`
Configurer le type d'horloge.

```assembly
_wait.setClock #0     ; Configurer pour 1MHz
_wait.setClock #1     ; Configurer pour 3.579545MHz
```

### `_wait.cycles.inline cycles`
Temporisation précise en cycles (code inline).

```assembly
_wait.cycles.inline #17    ; Attendre exactement 17 cycles
_wait.cycles.inline #100   ; Attendre exactement 100 cycles
```

### `_wait.frames frames`
Attendre le nombre de frames (50Hz).

```assembly
_wait.frames #2    ; Attendre 2 frames (40ms)
_wait.frames #5    ; Attendre 5 frames (100ms)
```

## Exemples d'utilisation

### Exemple 1 : Clignotement LED

```assembly
; Faire clignoter une LED 5 fois
ldb     #5                     ; 5 clignotements
@blinkLoop
    lda     #$FF               ; Allumer la LED
    sta     led.port
    _wait.ms #500              ; Attendre 500ms
    lda     #$00               ; Éteindre la LED
    sta     led.port
    _wait.ms #500              ; Attendre 500ms
    decb
    bne     @blinkLoop
```

### Exemple 2 : Temporisation précise

```assembly
; Temporisation de 5ms selon la fréquence
ldx     #5000                  ; 5ms × 1000 cycles (1MHz)
bsr     wait.cycles
; ou
ldx     #17895                 ; 5ms × 3579 cycles (3.579545MHz)
bsr     wait.cycles
```

### Exemple 3 : Détection automatique de fréquence

```assembly
; La routine détecte automatiquement la fréquence
_wait.ms.auto #100             ; Attendre 100ms
```

## Configuration

### Variable globale

```assembly
clock.type      fcb     0       ; 0 = 1MHz, 1 = 3.579545MHz
```

### Configuration au démarrage

```assembly
; Au début de votre programme
_wait.setClock #0              ; Pour 1MHz
; ou
_wait.setClock #1              ; Pour 3.579545MHz
```

## Précision

- **Millisecondes** : Précision au cycle près (±1 cycle)
- **Microsecondes** : Précision limitée par la fréquence d'horloge
- **Cycles** : Précision maximale (1 cycle près)

## Limitations

1. **Temporisation en millisecondes** : Maximum 255ms par appel
2. **Temporisation en microsecondes** : Maximum 255µs par appel
3. **Temporisation en cycles** : Maximum 65535 cycles par appel
4. **Fréquences supportées** : 1MHz et 3.579545MHz uniquement

## Performance

- **Taille du code** : ~150 bytes
- **Temps d'exécution** : Optimisé pour chaque fréquence
- **Utilisation mémoire** : 1 byte pour la configuration

## Intégration

Pour intégrer ces routines dans votre projet :

1. Inclure les fichiers :
```assembly
include "engine/timing/wait.asm"
include "engine/timing/wait.macro.asm"
```

2. Configurer la fréquence d'horloge au démarrage
3. Utiliser les macros ou appeler directement les routines 