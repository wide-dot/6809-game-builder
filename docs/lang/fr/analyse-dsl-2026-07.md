# Un langage de définition custom ? — analyse (31/07/2026)

Étude de l'alternative « DSL externe » au couple XML + contrat d'attributs
(cf. `analyse-config-2026-07.md`).

## 1. Ce qu'un DSL apporterait réellement

- **littéraux du domaine** (`$A000`, `0x4000`, un jour `16K` ou `$4000-6`)
  tokenisés et typés — *capturable sans DSL* comme type `HEX_INT` du
  contrat ;
- **validation = grammaire** : attribut inconnu, mot-clé mal placé, valeur
  intypable → erreurs de parsing avec position, avant exécution — c'est le
  même investissement sémantique que le contrat, sous une autre syntaxe ;
- **messages d'erreur au sommet de l'état de l'art** (on possède le
  parseur) — l'argument intrinsèque le plus fort ;
- **concision** (~40 % de volume en moins sur maquette) ; blocs bruts
  naturels pour l'asm inline.

## 2. Ce qu'un DSL coûte réellement

- **le parseur est les 20 % faciles** ; l'incompressible : récupération
  d'erreur multiple, évolution de grammaire avec compatibilité, spec du
  langage ;
- **la spirale d'expressivité** : variables, puis conditions, puis boucles —
  la trajectoire CMake/Gradle-Groovy. Le domaine générera ces demandes
  (les 3 configs mplus quasi identiques appellent déjà du paramétrage) ;
  en XML on duplique (laid mais borné), en DSL maison chaque concession se
  paie à vie ;
- **outillage de zéro** : coloration, complétion, LSP, formateur — et les
  assistants IA connaissent XML/YAML nativement, pas un DSL maison ;
- **la GUI prévue** rend le round-trip DSL (avec commentaires → CST)
  nettement plus coûteux que le round-trip d'un arbre XML ;
- **précédent v1** : la hiérarchie `.properties` était déjà un DSL du
  pauvre, et son illisibilité est une raison d'être de la v2. Leçon : le
  domaine finit toujours par exiger un langage plus riche que prévu — la
  question est *sur quoi* on le fait reposer.

## 3. Ce que la question révèle : le manque est sémantique, pas syntaxique

Ce qui manque au langage de définition actuel, indépendamment de sa forme :

- **les scènes ne sont pas déclarées** : ce sont des `.asm` écrits à la main
  (triplets page/adresse/fileid) qui dupliquent des informations connues de
  la config — source de la classe d'erreurs « destination incohérente » ;
- **les régions/couches de `groups.md` n'existent nulle part** : le
  vérificateur au build différé n'a rien à vérifier tant qu'elles ne sont
  pas déclarées ;
- **le pipeline projet-de-jeu v1** (objets, sprites, animations, game
  modes) n'a pas d'équivalent v2 — la plus grosse extension à venir.

Ce pouvoir déclaratif s'exprime en XML (`<scene>`, `<region>`, `<layer>`
avec génération des tables et vérification des tailles) aussi bien qu'en
DSL. La différence entre les deux options n'est pas là ; elle est dans les
coûts du §2.

## 4. Décision

**Pas de DSL externe maintenant.** Trois infléchissements retenus :

1. le contrat d'attributs est conçu comme **modèle sémantique à front-ends
   interchangeables** (XML aujourd'hui, GUI demain, DSL un jour si
   justifié), avec un mini-langage de *valeurs* typées (`HEX_INT`, porte
   ouverte à `16K`/arithmétique) ;
2. **étendre le déclaratif** là où ça corrige des erreurs réelles : scènes
   déclarées (tables générées), régions/couches déclarées (vérificateur de
   groups.md) ;
3. **critères de déclenchement explicites** pour reposer la question :
   (a) le pipeline projet-de-jeu v2 fait exploser le vocabulaire, ou
   (b) le besoin de variantes impose condition/boucle. Alors : DSL **comme
   façade au-dessus du même modèle**, jamais comme format de stockage.
