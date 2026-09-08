# Le config du banc est DERIVE de celui du jeu : meme carte memoire, memes
# fichiers communs, un seul game mode (main.asm) a la place du title.
# Rejeu : python3 gen-config.py   (depuis ce repertoire)
import sys
src=open('../../to8.config.xml').read().split('\n')
def find(pred, start=0):
    for i in range(start,len(src)):
        if pred(src[i]): return i
    raise SystemExit("marqueur absent")
i_comp=find(lambda l:'<composition name="boot">' in l)
i_layout_end=find(lambda l:'</layout>' in l)
i_floppy=find(lambda l:'<floppydisk' in l)
i_dir0=find(lambda l:'<directory id="0"' in l)
i_dir9=find(lambda l:'<directory id="9"' in l)     # l'amorcage : fondu + splash, avant le 0
i_dir0_end=find(lambda l:l.strip()=='</directory>', i_dir0)   # le 0 = le resident et scenes.boot, rien d'autre depuis le 07/09
i_loaderdef=find(lambda l:'boot.CHECK_MEMORY_EXT' in l)
k=i_loaderdef-8
assert src[k].strip().startswith('<!-- Le pool du loader'), src[k]
i_fd=find(lambda l:'<fd ' in l)
out=['<!-- GENERE par gen-config.py depuis ../../to8.config.xml : ne pas editer. -->']
out+=src[:i_comp]
comps=['            <composition name="boot">','                <scene name="scenes.boot"/>','            </composition>']
for n in ['title']+['stage%d'%d for d in range(1,9)]:
    comps+=['            <composition name="%s">'%n,'                <scene name="scenes.boot"/>','                <scene name="scenes.bench"/>','            </composition>']
out+=['            <!-- BANC : neuf etats identiques — le moteur nomme les huit stages',
      '                 dans game.stage.states, le banc n\'en a qu\'un. -->']+comps
out+=src[i_layout_end:i_floppy+1]
# une seule section, comme le jeu depuis le 08/09/2026 : les repertoires sont
# colocalises (colocate="true", copie avec leurs lignes), tables et liens dans DATA
out+=['            <section name="DATA"  track="1" face="0" sector="1"/>',
      '            <define symbol="OverlayMode"/>',
      '            <define symbol="LOG_INFO"/>']
# python3 gen-config.py --no-text : la saisie sans son texte (mesure des
# blasts et des Pata-Pata seuls, 05/09/2026) — jamais dans le jeu.
if '--no-text' in sys.argv:
    out+=['            <define symbol="RANKING_TEXT_OFF"/>']
out+=['']
# le repertoire 9 tel quel (le banc amorce comme le jeu), renumerote 1 : les
# ids de repertoires doivent se suivre, et le banc n'a que le 0 et celui-la
out+=[l.replace('<directory id="9"','<directory id="1"') for l in src[i_dir9:i_dir0]]
out+=src[i_dir0:i_dir0_end]
out+=['                <!-- ===== LE BANC, a la place du title ===================== -->',
      '                <file name="bench.main" linkdata="DATA" region="stage">',
      '                    <lwasm gensource="gen/bench/main.asm">',
      '                        <asm filename="gen/directories/disk0/entries.asm"/>',
      '                        <asm filename="main.asm"/>',
      '                        <png2pal section="palette" symbol="Pal_stage" filename="src/stages/01/palette/pal.png"/>',
      '                        <png2pal section="palette" symbol="Pal_black" filename="engine/palette/color/Pal_black.png"/>',
      '                    </lwasm>',
      '                </file>','']
out+=['','                <scene name="scenes.bench" section="DATA" gensource="gen/scenes/bench.asm">',
      '                    <load name="bench.main"/>','                </scene>','            </directory>','']
out+=[l.replace('loader.DEFAULT_SCENE_DIR_ID    equ 9','loader.DEFAULT_SCENE_DIR_ID    equ 1') for l in src[k:i_fd]]
out+=['            <fd  filename="to8.fd"/>','        </floppydisk>','    </target>','</configuration>']
# les regions SANS adresse prennent celle de leur contenu ; le banc n'en a
# aucun, le builder refuserait — on les retire (aucun fichier du banc n'y vit).
out=[l for l in out if not (l.strip().startswith('<region') and 'address=' not in l)]
out=[l for l in out if 'gen/directories/dir10/entries.asm' not in l]   # pas de repertoire 10 au banc
open('to8.config.xml','w').write('\n'.join(out))
print("config :", len(out), "lignes ; fichiers :", sum(1 for l in out if '<file name=' in l))
