#!/usr/bin/env python3
"""Réduire un effet sonore Master System (sortie de `vgm2sfx`) au format joué
par notre pilote YM2413 (`src/common/fx/soundfx/soundFX.asm`).

## D'où vient la donnée

La chaîne complète, et elle est rejouable de bout en bout :

    R-Type Master System (version FM japonaise, YM2413)
      -> capture VGM            games/r-type/reference/sms/sfx/<n>.vgm
      -> vgm2sfx                games/r-type/reference/sms/sfx/asm/<n>.asm
      -> CET OUTIL              le bloc au format de notre pilote

`vgm2sfx` (toolbox/audio/vgm2sfx) ne garde du flux VGM que les écritures
YM2413, saute les écritures redondantes et convertit les attentes en trames
50 Hz PAL. Il sort une ligne `fcb $registre,$donnée,délai ; ch:N` par
écriture, la borne d'origine jouant sur ses neuf voies.

    java -cp "repo/*" com.widedot.toolbox.audio.vgm2sfx.MainCommand \
         -f reference/sms/sfx/18-fire.vgm -g reference/sms/sfx/asm/18-fire.asm

## Ce que fait la réduction

Notre pilote joue un effet sur UNE voie, et le numéro de voie vit dans
l'en-tête du bloc, pas dans les registres. Les six effets déjà portés
(tir, explosion, bonus, accrochage du pod, tir chargé, joueur touché) ont
été réduits à la main ; cet outil rejoue les cinq gestes qu'on y lit :

1. **le préambule d'init part** — les écritures de l'instrument
   personnalisé (registres $00-$0E) et le bloc qui initialise les neuf
   voies, que la Master System refait avant chaque son ;
2. **une seule voie est gardée** — celle qui porte le son. Un effet qui
   s'étale sur plusieurs voies (le joueur touché en occupe trois) perd les
   autres ; le choix par défaut est la voie la plus fournie, et l'option
   `--voie` permet d'auditionner les autres ;
3. **le numéro de voie sort du registre** — `$18` devient `$10`, le pilote
   remet la voie de l'en-tête ;
4. **la coupure de note disparaît** — la Master System écrit la paire
   « note off » puis « note on » ($20 sans puis avec le bit 4) ; le portage
   ne garde que le « note on » ;
5. **le volume est poussé à fond** — le quartet bas du registre $30 est mis
   à 0, et la valeur d'origine est notée en commentaire (`; vol:2`), comme
   dans les blocs écrits à la main ;
6. **l'instrument personnalisé est réécrit en tête quand le corps s'en
   sert** — cinq sons du corpus (35, 48, 49, 50, 51) jouent sur l'instrument
   0, celui que les registres $00-$07 définissent, et cette définition vit
   dans le préambule que le geste 1 coupe. L'outil la retient (la dernière
   valeur écrite dans chaque registre avant le corps) et la remet en tête du
   bloc en huit commandes ordinaires, délai 0 — les registres sous $0F sont
   écrits tels quels par le pilote. La commande `$FF` du pilote, prévue pour
   ça, n'est pas employée : son octet de délai est relu à l'adresse de la
   table, c'est-à-dire n'importe quoi (`lda -1,x` après `leax 3,x`). Aucun
   des six blocs écrits à la main n'en avait besoin : ils jouent tous sur un
   instrument de la ROM du YM2413 ;
7. **la remise à plat finale part** — la Master System clôt chaque son en
   remettant la voie sur l'instrument 0 à volume 15, muet ; ce n'est pas du
   son, et les blocs à la main ne la gardent pas.

Les délais sont conservés tels quels : ce sont déjà des trames 50 Hz.

## Emploi

    tools/sms_sfx_to_soundfx.py reference/sms/sfx/asm/18-fire.asm
    tools/sms_sfx_to_soundfx.py --tout --sortie reference/sms/sfx/soundfx
    tools/sms_sfx_to_soundfx.py --calibrer   # rejoue les six sons portés

`--calibrer` compare la sortie de l'outil aux six blocs de `soundFX.asm` :
c'est la preuve que la règle ci-dessus est bien celle qui a été appliquée à
la main, et le garde-fou si l'outil change.
"""

import argparse
import os
import re
import sys

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASM = os.path.join(RACINE, 'reference/sms/sfx/asm')
PORTES = os.path.join(RACINE, 'src/common/fx/soundfx/soundFX.asm')

# Registres YM2413 dont le quartet bas porte le numéro de voie.
REG_FREQ_LSB = 0x10   # fréquence, poids faible
REG_FREQ_MSB = 0x20   # bloc + note on/off
REG_INST_VOL = 0x30   # instrument (quartet haut) + volume (quartet bas)

LIGNE = re.compile(
    r'^\s*fcb\s+\$([0-9A-Fa-f]{2}),\$([0-9A-Fa-f]{2}),(\d+)\s*;(.*)$')
CH = re.compile(r'ch:(\d+)')


def lire(chemin):
    """[(registre, donnée, délai, voie ou None)] depuis une sortie vgm2sfx."""
    out = []
    for l in open(chemin):
        m = LIGNE.match(l)
        if not m:
            continue
        reg, dat, delai = int(m.group(1), 16), int(m.group(2), 16), int(m.group(3))
        mc = CH.search(m.group(4))
        out.append((reg, dat, delai, int(mc.group(1)) if mc else None))
    return out


def sans_preambule(cmds):
    """Coupe l'init : tout ce qui précède la DERNIÈRE écriture $30 du bloc
    qui met les neuf voies à plat. On la reconnaît à ce qu'elle écrit la
    même donnée sur les neuf voies d'affilée."""
    dernier = -1
    for i in range(len(cmds) - 8):
        f = cmds[i:i + 9]
        if all(c[0] & 0xF0 == REG_INST_VOL for c in f) \
           and sorted(c[3] for c in f) == list(range(9)) \
           and len({c[1] for c in f}) == 1:
            dernier = i + 8
    return cmds[dernier + 1:] if dernier >= 0 else cmds


def instrument_perso(cmds):
    """[8 octets] : la dernière valeur écrite dans chacun des registres
    $00-$07 avant le corps (geste 6). Un registre jamais écrit vaut 0."""
    inst = [0] * 8
    corps = len(cmds) - len(sans_preambule(cmds))
    for reg, dat, _, _ in cmds[:corps]:
        if reg <= 7:
            inst[reg] = dat
    return inst


def utilise_instrument_0(cmds, voie):
    """Le corps sélectionne-t-il l'instrument 0 sur la voie gardée, pour en
    JOUER ? La Master System termine chaque son en remettant la voie à plat
    — instrument 0, volume 15 (muet) — et cette remise à plat n'est pas un
    usage : seul compte un instrument 0 à volume audible."""
    return any(reg & 0xF0 == REG_INST_VOL and v == voie
               and dat >> 4 == 0 and dat & 0x0F != 0x0F
               for reg, dat, _, v in cmds)


def voies(cmds):
    """{voie: nombre de commandes} sur le corps du son."""
    d = {}
    for _, _, _, v in cmds:
        if v is not None:
            d[v] = d.get(v, 0) + 1
    return d


def reduire(cmds, voie, report=False):
    """Applique les gestes 3, 4 et 5 sur la voie retenue.

    Le délai d'une ligne `vgm2sfx` est l'attente qui SUIT sa commande. Sur un
    son étalé sur plusieurs voies, deux lectures sont donc possibles : garder
    la voie retenue AVEC ses seuls délais, ou lui faire hériter de ceux des
    commandes écartées. Le choix se fait tout seul :

    - **son sur une seule voie** — tous les délais sont déjà sur la voie
      gardée, les deux lectures donnent le même résultat, et c'est celle des
      six blocs écrits à la main ;
    - **son sur plusieurs voies** — les délais sont répartis entre les voies,
      et sans report la réduction en perd la totalité : six des cinquante-
      quatre sons du corpus sortaient avec une durée de ZÉRO trame, donc
      inaudibles. Le report est alors obligatoire.

    `--reporter-delais` et `--delais-voie` forcent l'une ou l'autre lecture.
    """
    out = []
    reste = 0
    for i, (reg, dat, delai, v) in enumerate(cmds):
        base = reg & 0xF0
        garde = v == voie
        # geste 4 : la coupure de note qui précède immédiatement le note on
        if garde and base == REG_FREQ_MSB and not (dat & 0x10):
            suite = next((c for c in cmds[i + 1:] if c[3] == voie), None)
            if suite and suite[0] & 0xF0 == REG_FREQ_MSB and (suite[1] & 0x10):
                garde = False
        if not garde:
            if report:
                reste += delai
            continue
        note = ''
        if base == REG_INST_VOL:
            note = ' ; vol:%d' % (dat & 0x0F)       # geste 5
            dat &= 0xF0
        out.append([base, dat, delai + reste, note])  # geste 3
        reste = 0
    if reste and out:
        out[-1][2] += reste
    return [tuple(c) for c in out]


def bloc(nom, cmds, voie, source, alternatives):
    """Le bloc asm, au format de src/common/fx/soundfx/soundFX.asm."""
    l = []
    l.append('; %s' % nom)
    l.append('; Source : %s (Master System FM), voie %d%s.' % (
        source, voie,
        ' — aussi sur ' + ', '.join('%d' % v for v in alternatives)
        if alternatives else ''))
    l.append('; Genere par tools/sms_sfx_to_soundfx.py, ne pas editer a la main.')
    l.append('%s' % nom)
    l.append('        ; header')
    l.append('        fcb     %-4d                ; Number of commands' % len(cmds))
    l.append('        fcb     5                   ; Channel number (5)')
    l.append('')
    for reg, dat, delai, note in cmds:
        l.append('        fcb     $%02X,$%02X,%d%s' % (reg, dat, delai, note))
        if delai:
            l.append('')
    return '\n'.join(l).rstrip() + '\n'


def convertir(chemin, voie=None, report=None):
    tout = lire(chemin)
    corps = sans_preambule(tout)
    v = voies(corps)
    if not v:
        return None, None, {}
    retenue = voie if voie is not None else max(v, key=lambda k: (v[k], k))
    if report is None:                 # le son multi-voies a besoin du report
        report = len(v) > 1
    cmds = list(reduire(corps, retenue, report))
    # geste 7 : la remise a plat finale de la voie (instrument 0, volume 15)
    # n'est pas du son — les blocs a la main ne la gardent pas.
    if cmds and cmds[-1][0] == REG_INST_VOL and cmds[-1][3] == ' ; vol:15':
        cmds.pop()
    if utilise_instrument_0(corps, retenue):                     # geste 6
        tete = [(reg, dat, 0, ' ; instrument perso' if reg == 0 else '')
                for reg, dat in enumerate(instrument_perso(tout))]
        cmds = tete + list(cmds)
    return cmds, retenue, v


def blocs_portes():
    """Les six blocs écrits à la main, pour la calibration."""
    txt = open(PORTES).read()
    out = {}
    for m in re.finditer(r'^(soundFX\.\w+\.data)\n(.*?)(?=\n^soundFX\.\w+\.data|\Z)',
                         txt, re.S | re.M):
        cmds = []
        for l in m.group(2).split('\n'):
            mm = LIGNE.match(l) or re.match(
                r'^\s*fcb\s+\$([0-9A-Fa-f]{2}),\$([0-9A-Fa-f]{2}),(\d+)\s*$', l)
            if mm:
                cmds.append((int(mm.group(1), 16), int(mm.group(2), 16),
                             int(mm.group(3))))
        out[m.group(1)] = cmds
    return out


# nom du bloc porté -> fichier Master System dont il est tiré
CALIBRAGE = {
    'soundFX.FireSound.data':      '18-fire',
    'soundFX.FireBlastSound.data': '33-fire-blast',
    'soundFX.PlayerHitSound.data': '36-player-hit',
    'soundFX.PodAttachSound.data': '38-pod-attach',
    'soundFX.BonusSound.data':     '40-bonus',
    'soundFX.ExplosionSound.data': '46-explosion-0',
}


def calibrer():
    portes = blocs_portes()
    print('%-16s %-16s %-8s %s' % ('bloc a la main', 'source SMS', 'voie',
                                   'accord (meilleur alignement)'))
    for nom, src in sorted(CALIBRAGE.items(), key=lambda x: x[1]):
        ref = portes.get(nom, [])
        best = None
        for v in voies(sans_preambule(lire(os.path.join(ASM, src + '.asm')))):
            cmds, _, _ = convertir(os.path.join(ASM, src + '.asm'), v, False)
            got = [(r, d, t) for r, d, t, _ in cmds]
            # l'auteur ajoute parfois une note en tete : on cherche le
            # decalage qui fait le mieux concorder les deux suites.
            for dec in range(-3, 4):
                a = ref[dec:] if dec > 0 else ref
                b = got if dec > 0 else got[-dec:]
                n = sum(1 for x, y in zip(a, b) if x == y)
                score = n / max(len(a), len(b), 1)
                if best is None or score > best[0]:
                    best = (score, v, len(got), dec)
        print('%-16s %-16s %-8d %3d%% sur %d commandes%s'
              % (nom.replace('soundFX.', '').replace('.data', ''), src,
                 best[1], round(100 * best[0]), best[2],
                 '' if best[3] == 0 else
                 '  (%d commande(s) ajoutee(s) a la main en tete)' % abs(best[3])))


def main():
    ap = argparse.ArgumentParser(add_help=False)
    ap.add_argument('fichier', nargs='?')
    ap.add_argument('--voie', type=int, default=None)
    ap.add_argument('--tout', action='store_true')
    ap.add_argument('--sortie', default=None)
    ap.add_argument('--calibrer', action='store_true')
    ap.add_argument('--reporter-delais', action='store_true')
    ap.add_argument('--delais-voie', action='store_true')
    ap.add_argument('-h', '--help', action='store_true')
    a = ap.parse_args()
    if a.help or (not a.fichier and not a.tout and not a.calibrer):
        print(__doc__)
        return 0
    if a.calibrer:
        calibrer()
        return 0
    fichiers = (sorted(os.path.join(ASM, f) for f in os.listdir(ASM)
                       if f.endswith('.asm')) if a.tout else [a.fichier])
    if a.sortie:
        os.makedirs(a.sortie, exist_ok=True)
    for f in fichiers:
        base = os.path.basename(f)[:-4]
        report = True if a.reporter_delais else (False if a.delais_voie else None)
        cmds, voie, v = convertir(f, a.voie, report)
        if not cmds:
            print('%-20s VIDE (aucune commande apres le preambule)' % base,
                  file=sys.stderr)
            continue
        alt = sorted(k for k in v if k != voie)
        nom = 'soundFX.sms%s.data' % re.sub(r'[^0-9A-Za-z]', '', base.title())
        texte = bloc(nom, cmds, voie, base, alt)
        if a.sortie:
            open(os.path.join(a.sortie, base + '.asm'), 'w').write(texte)
            print('%-20s voie %d, %3d commandes%s' % (
                base, voie, len(cmds),
                '  (aussi ' + ','.join(str(x) for x in alt) + ')' if alt else ''))
        else:
            print(texte)
    return 0


if __name__ == '__main__':
    sys.exit(main())
