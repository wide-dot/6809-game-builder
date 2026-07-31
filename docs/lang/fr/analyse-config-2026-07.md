# Contrat d'attributs & format de configuration — analyse (31/07/2026)

Analyse préalable au chantier « contrat d'attributs », incluant l'étude
XML vs YAML demandée. Basée sur le corpus réel : 1 236 lignes de config sur
8 fichiers, 22 éléments, 19 attributs, 65 sites d'appel `Attribute.get*`.

## 1. Nature du fichier de configuration

Un `*.config.xml` n'est pas un fichier de réglages : c'est un **document de
construction**, avec quatre propriétés structurelles :

1. **l'ordre est sémantique, deux fois** : l'ordre des `<direntry>` détermine
   les file ids ; l'ordre des enfants hétérogènes d'un direntry (`<bin>` puis
   `<lwasm>`…) détermine la concaténation, donc la disposition mémoire ;
2. **les éléments se répètent et se mélangent** (39 direntries dans loader-ut,
   membres hétérogènes entrelacés dans `<lwasm>`) ;
3. **il transporte du texte brut à blancs significatifs** (121 éléments
   `xml:space="preserve"` d'assembleur inline) ;
4. **le vocabulaire est petit et fermé** (22 éléments / 19 attributs).

Les formats « clé/valeur » sont faits pour des réglages ; les formats
« document » pour ceci.

## 2. Le contrat actuel est implicite — défauts mesurés

- **Attribut inconnu silencieusement ignoré** : aucun code n'énumère
  `node.getAttributes()` ; une faute de frappe fait retomber l'attribut
  attendu sur sa valeur par défaut. Mécanisme identique au bug du garde-fou
  16 Ko (clé `directory.maxsize` vs `direntry.maxsize`, inactif depuis
  l'origine).
- **Clé de defaults ressaisie à la main** à chaque site : 8 handlers sur 16
  lisaient des clés sous un namespace étranger avant correction.
- **Aucune position source** : `ImmutableNode` (commons-configuration2) ne
  conserve ni fichier ni ligne (vérifié sur le jar). D'où des messages
  « fd.filename attribute is missing » sans localisation.
- **Typage artisanal** : `Integer.decode` accepte `0x4000` mais pas `$4000` ;
  `getBoolean` vaut `false` pour tout sauf `"true"` exact ; `getIntegerOpt`
  NPE (jamais appelé).
- **Interpolation `${...}` active** dans `XMLConfiguration`, inutilisée,
  non documentée — substitution silencieuse possible.

Ces défauts sont ceux du **décodage**, pas du format.

## 3. Proposition : le contrat vit sur le handler

Le registre `Handlers` fournit l'emplacement : chaque handler est enregistré
avec un **descripteur** (attributs : nom, type, requis/optionnel/défaut,
doc ; catégories d'enfants admises). Ce descripteur produit :

1. **validation en passe préalable** sur l'arbre complet : attribut inconnu,
   requis absent, valeur intypable → erreurs nommant l'élément, l'attribut,
   les candidats valides, et la position ;
2. **clé de defaults dérivée** (`<élément>.<attribut>`) : la classe de bugs
   « namespace divergent » devient inexprimable ; les `<default name=...>`
   sont validés contre les descripteurs ;
3. **positions source** : loader StAX (~100 lignes) construisant le même
   arbre en conservant ligne/colonne, sortie de commons-configuration2 ;
4. **doc de référence générée** depuis les descripteurs ;
5. **XSD généré** → validation et autocomplétion dans tout éditeur.

Type `HEX_INT` unifiant `$…`/`0x…`/décimal. Sévérité : erreur dure d'emblée
(corpus interne petit, mise en conformité en une passe).

## 4. XML vs YAML

### Forces de XML pour ce document

ordre hétérogène natif ; répétition native ; tout-est-chaîne (les `$A000`,
`0x100`, `16` arrivent tels qu'écrits, le consommateur type) ; fermeture
explicite = erreurs de structure bruyantes ; XSD mûr et outillé partout.

### Faiblesses de l'usage actuel (décodage, pas format)

commons-configuration2 est une lib de settings utilisée comme API d'arbre
(pas de positions, interpolation surprise, adressage `[@attr]` piégeux —
cf. bug `[sectorperblock]`) ; asm inline pénible (une ligne = un élément,
alors qu'un CDATA multi-lignes est possible) ; verbosité réelle mais bornée
(~15-20 % de taxe syntaxique) ; aucun schéma exploité.

### YAML — avantages réels

block scalars pour l'asm inline (le gain le plus net) ; positions source
natives (SnakeYAML `Mark`) ; moins de bruit ; yaml-language-server + JSON
Schema donne aussi validation/autocomplétion.

### YAML — inconvénients, précisément sur nos points sensibles

- **typage implicite** (SnakeYAML = YAML 1.1) : `0x4000` → int, `no` →
  false, `0755` → octal, `12:34` → 754 (sexagésimal) ; discipline de
  guillemets non vérifiable ;
- **ordre hétérogène non natif** : convention « séquence de mappings
  mono-clé » requise sur la propriété la plus critique du format ;
- **indentation structurante et silencieuse** : un bloc désindenté devient
  un autre document *valide* — la classe de pannes silencieuses qu'on
  combat ;
- **migration intégrale** du corpus, de la doc et des habitudes pour un gain
  modeste une fois le contrat en place.

TOML : pas de structure ordonnée hétérogène — éliminé. JSON : pas de
commentaires — éliminé.

### Facteur GUI

Une GUI est prévue : le format devient une cible d'écriture machine, les
arguments d'ergonomie humaine s'affaiblissent, et le round-trip avec
commentaires (trivial en XML, fragile en YAML côté Java) devient le critère.

## 5. Verdict

**Garder XML. Remplacer le décodage. Ajouter le contrat.** La douleur est à
~90 % dans la couche de lecture et l'absence de contrat. Trajectoire :
loader StAX avec positions → descripteurs typés + validation (migration
handler par handler sous comparaison binaire) → XSD + doc générés → CDATA
multi-lignes pour l'asm inline. YAML ne serait réévalué que comme façade
optionnelle au-dessus du même arbre, jamais comme second format maintenu.
