# Documentation du Format Binaire MUB (MUCOM88 Binary)

## Vue d'ensemble

Le format MUB (MUCOM88 Binary) est le format compilé utilisé par MUCOM88 pour stocker les données musicales. Cette documentation est basée sur l'analyse comparative des implémentations Z80 (original) et 6809 (port moderne).

## Structure du fichier MUB

### En-tête du fichier (32 octets)

```
Offset  Taille  Description
------  ------  -----------
0x00    4       Magic number "MUB8"
0x04    4       Offset vers les données musicales
0x08    4       Taille des données musicales
0x0C    4       Offset vers les données de tag
0x10    4       Taille des données de tag
0x14    4       Offset vers les données PCM
0x18    4       Taille des données PCM
0x1C    2       Compteur de saut
0x1E    2       Ligne de saut
```

### Données musicales

Les données musicales suivent immédiatement l'en-tête et contiennent les flux de commandes pour chaque canal.

## Encodage des commandes

### Notes et silences (0x80-0xFE)

- **0x80** : Silence (rest)
- **0x81-0xFE** : Notes musicales

#### Encodage des notes
```
0x81 = Do (C)     0x82 = Do# (C#)   0x83 = Ré (D)     0x84 = Ré# (D#)
0x85 = Mi (E)     0x86 = Fa (F)     0x87 = Fa# (F#)   0x88 = Sol (G)
0x89 = Sol# (G#)  0x8A = La (A)     0x8B = La# (A#)   0x8C = Si (B)
```

Les notes sont répétées pour chaque octave :
- Octave 0 : 0x81-0x8C
- Octave 1 : 0x8D-0x98
- Octave 2 : 0x99-0xA4
- etc.

Chaque note est suivie d'un octet de durée.

### Commandes principales (0xF0-0xFF)

| Opcode | Commande MML | Description | Paramètres |
|--------|--------------|-------------|------------|
| 0xF0 | @ | Changement de voix | 1 octet (numéro de voix) |
| 0xF1 | v | Volume | 1 octet (0-15) |
| 0xF2 | D | Désaccord (detune) | 2 octets (valeur signée) |
| 0xF3 | q | Durée de gate | 1 octet (1-8) |
| 0xF4 | - | LFO | Paramètres variables |
| 0xF5 | [ | Début de répétition | 1 octet (nombre de répétitions) |
| 0xF6 | ] | Fin de répétition | Aucun |
| 0xF7 | P | Bruit/Mix (SSG) ou MDSET (FM) | 1 octet |
| 0xF8 | - | Stéréo/Pan (FM) ou paramètres bruit (SSG) | 1 octet |
| 0xF9 | - | Définition de flag | 1 octet |
| 0xFA | y/E | Écriture registre (FM) ou Enveloppe (SSG) | Variables |
| 0xFB | ) | Augmentation volume | Aucun |
| 0xFC | - | LFO matériel | Paramètres variables |
| 0xFD | & | Liaison | Aucun |
| 0xFE | / | Saut de répétition | Aucun |
| 0xFF | - | Commandes étendues | Voir section suivante |

### Commandes étendues (0xFF xx)

Les commandes étendues utilisent un système à deux octets : 0xFF suivi d'un sous-code.

| Sous-code | Description | Paramètres |
|-----------|-------------|------------|
| 0xF0 | Mode volume PCM | 1 octet |
| 0xF1 | Enveloppe matérielle 's' | 1 octet (0-15) |
| 0xF2 | Période d'enveloppe matérielle | 2 octets |
| 0xF3 | Réverbération | 1 octet |
| 0xF4 | Mode réverbération | 1 octet |
| 0xF5 | Commutateur réverbération | 1 octet |
| 0xF6 | **Enveloppe software** | 5 octets (ADSR) |

#### Détail de l'enveloppe software (0xFF 0xF6)

L'enveloppe software utilise 5 paramètres ADSR :

```
Paramètre 1 : Attack rate (vitesse d'attaque)
Paramètre 2 : Decay rate (vitesse de déclin)
Paramètre 3 : Sustain level (niveau de maintien)
Paramètre 4 : Sustain rate (vitesse de maintien)
Paramètre 5 : Release rate (vitesse de relâchement)
```

## Structure des canaux

Le format MUB supporte 11 canaux :

- **Canaux FM (0-5)** : 6 canaux de synthèse FM
- **Canaux SSG (6-8)** : 3 canaux de générateur de son simple
- **Canal Rhythm (9)** : 1 canal de percussion
- **Canal ADPCM (10)** : 1 canal d'échantillonnage

## Système de répétition

Le format MUB implémente un système de répétition avec pile :
- Jusqu'à 8 niveaux d'imbrication par canal
- Chaque entrée occupe 4 octets (adresse + compteur)
- Répétition maximale : 255 fois

## Différences entre implémentations

### Z80 original vs 6809 port

1. **Enveloppe software** : Extension ajoutée dans le port 6809
2. **Commandes étendues** : Plus complètes dans le port 6809
3. **Gestion des canaux** : Structure optimisée pour l'architecture 6809

### Compatibilité

Le port 6809 maintient la compatibilité avec le format original Z80 tout en ajoutant des fonctionnalités étendues.

## Exemples d'encodage

### Note Do octave 4, durée 48

```
0x9D 0x30
```

### Changement de voix 5

```
0xF0 0x05
```

### Début de répétition 3 fois

```
0xF5 0x03
```

### Enveloppe software ADSR

```
0xFF 0xF6 0x0A 0x05 0x80 0x02 0x08
```
(Attack=10, Decay=5, Sustain=128, Sustain rate=2, Release=8)

## Notes techniques

- **Endianness** : Little-endian pour les valeurs multi-octets
- **Taille maximale** : Limitée par la mémoire disponible
- **Optimisation** : Tables de saut pour un décodage rapide
- **Timing** : Basé sur 48 ticks par temps, 60 FPS

Cette documentation fournit une base complète pour comprendre et implémenter le format binaire MUB dans d'autres systèmes ou pour créer des outils de conversion.

---

# Documentation du Langage MML (Music Macro Language) MUCOM88

## Vue d'ensemble

MML (Music Macro Language) est le langage de programmation musicale utilisé par MUCOM88 pour composer de la musique. Il permet de décrire précisément les notes, rythmes, instruments et effets sonores.

## Syntaxe de base

### Notes musicales

```
c d e f g a b    Notes naturelles (Do, Ré, Mi, Fa, Sol, La, Si)
c+ d+ f+ g+ a+   Notes dièses (Do#, Ré#, Fa#, Sol#, La#)
c- d- e- f- g- a- b-  Notes bémols
r                Silence (rest)
```

### Durées

Les durées sont exprimées en fractions de ronde :

```
1    Ronde (note entière)
2    Blanche (demi-note)  
4    Noire (quart de note)
8    Croche (huitième de note)
16   Double-croche (seizième de note)
32   Triple-croche (trente-deuxième de note)
```

#### Durées pointées et liées

```
c4.    Note pointée (durée × 1.5)
c4&8   Notes liées (noire + croche)
```

### Octaves

```
o0-o8    Définition d'octave absolue
<        Octave précédente
>        Octave suivante
```

## Commandes de canal

### Volume

```
v0-v15   Volume du canal (0 = silence, 15 = maximum)
)        Augmentation du volume (+1)
(        Diminution du volume (-1)
```

### Tempo

```
t60-t300  Tempo en BPM (battements par minute)
```

### Instruments (voix)

```
@0-@255   Sélection d'instrument/voix
```

## Commandes avancées

### Détune (désaccord)

```
D-8192,8191   Désaccord fin en centièmes de demi-ton
```

### Gate time (durée d'attaque)

```
q1-q8    Durée d'attaque (1 = court, 8 = long)
```

### Répétitions

```
[n       Début de répétition (n fois)
]        Fin de répétition
/        Saut de répétition (dernière itération seulement)
```

#### Exemple de répétition
```
[3 c d e f]    Joue "c d e f" trois fois
[2 c d /e f]   Première fois: "c d f", deuxième fois: "c d e f"
```

### LFO (Low Frequency Oscillator)

```
MP delay,speed,depth    LFO de pitch (vibrato)
MA delay,speed,depth    LFO d'amplitude (tremolo)
MF delay,speed,depth    LFO complet
M0                      Arrêt du LFO
```

### Liaison

```
&    Lie la note suivante (pas de nouvelle attaque)
```

## Commandes spécifiques aux canaux FM

### Mode SE (Sound Effect) - Canal 3 uniquement

```
MD d1,d2,d3,d4    Définit le détune pour chaque opérateur
```

### Stéréo/Pan

```
p0    Centre
p1    Gauche
p2    Droite  
p3    Gauche et droite
```

### Écriture directe de registres

```
y reg,val    Écrit la valeur 'val' dans le registre 'reg' du YM2608
```

### LFO matériel

```
HL freq,pms,ams    Configure le LFO matériel du YM2608
```

## Commandes spécifiques aux canaux SSG

### Contrôle du bruit

```
P0-P31    Configuration du mélangeur bruit/tonalité
```

### Paramètres du générateur de bruit

```
w0-w31    Fréquence du générateur de bruit
```

### Enveloppe matérielle

```
E mode,period    Configure l'enveloppe matérielle SSG
```

#### Modes d'enveloppe SSG
```
0-15    Différentes formes d'enveloppe (sawtooth, triangle, etc.)
```

## Commandes étendues

### Enveloppe software

```
s0-s15    Sélection d'enveloppe software prédéfinie
```

Les enveloppes software utilisent 5 paramètres ADSR :
- **Attack** : Vitesse de montée du volume
- **Decay** : Vitesse de descente après l'attaque  
- **Sustain Level** : Niveau de maintien
- **Sustain Rate** : Vitesse de décroissance pendant le maintien
- **Release** : Vitesse de descente après relâchement

### Mode volume PCM

```
PM mode    Définit le mode de volume pour les échantillons PCM
```

### Réverbération

```
R param         Active la réverbération
RM mode         Mode de réverbération
RS on_off       Commutateur réverbération
```

## Canal Rhythm (Percussion)

Le canal 9 est dédié aux percussions du YM2608 :

```
c    Bass Drum (grosse caisse)
d    Snare Drum (caisse claire)
e    Top Cymbal (cymbale)
f    Hi-Hat (charleston)
g    Tom
a    Rim Shot
```

## Canal ADPCM

Le canal 10 joue des échantillons ADPCM :

```
@0-@255   Sélection d'échantillon ADPCM
c-b       Hauteur de lecture de l'échantillon
```

## Exemples pratiques

### Mélodie simple
```
t120 o4 @1 v12
c4 d4 e4 f4 g2 a4 b4 >c2
```

### Avec répétitions et effets
```
t140 o5 @3 v10 q6
[2 c8 d8 e8 f8] g4 MP3,4,2 a2&4 M0
```

### Percussion
```
; Canal 9 (Rhythm)
t130 v15
[4 c4 r8 d8 r4 c8 d8]
```

### Multi-canal (exemple complet)
```
A t120 o4 @1 v12 [2 c4 e4 g4 >c4] <g2
B t120 o3 @2 v10 [2 c2 f2] g1  
C t120 o4 @5 v8 MP2,3,1 [4 e8 g8] M0 >c2
```

## Conseils de composition

1. **Utilisez les répétitions** pour réduire la taille des fichiers
2. **Gérez les octaves** avec `<` et `>` plutôt qu'avec `o`
3. **Variez les instruments** avec `@` pour enrichir la texture
4. **Exploitez les effets** (LFO, détune) avec modération
5. **Testez sur matériel** pour valider le rendu sonore

## Limitations techniques

- **Polyphonie** : 6 canaux FM + 3 canaux SSG + 1 rhythm + 1 ADPCM
- **Instruments** : 256 voix FM maximum
- **Répétitions** : 8 niveaux d'imbrication maximum
- **Tempo** : 60-300 BPM
- **Octaves** : 0-8

Cette documentation MML fournit tous les éléments nécessaires pour composer efficacement avec MUCOM88.