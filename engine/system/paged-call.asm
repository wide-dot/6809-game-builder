* ---------------------------------------------------------------------------
* paged.call
* ----------
* Appelle une routine qui vit dans une page RAM, depuis du code resident.
*
* C'est le pendant v2 de ce que la v1 obtenait en declarant un objet : la
* seule raison d'etre de cet objet etait de faire placer le code en banque
* RAM et de faire monter la page avant l'appel. En v2 les deux sont acquis
* autrement, et sans indirection :
*
*   - la PAGE est une constante d'assemblage. Une <region> du layout produit
*     l'equate <region>.page, et un <direntry> exporte <nom>$PAGE resolu au
*     chargement ; l'appelant ecrit donc la page en immediat.
*   - l'ADRESSE est un symbole de lien. L'unite EXPORTe son entree, le
*     re-link du chargement de scene la repointe.
*
* Un objet, lui, passe par Obj_Index_* parce que la WAVE le designe par
* identifiant au runtime. Une routine de dessin d'overlay est connue a
* l'assemblage : elle n'a rien a faire dans cet index.
*
* Contrairement a RunPgSubRoutine, aucune operande auto-modifiee : la page
* d'origine vit sur la pile, donc l'appel est reentrant.
*
* Le fenetrage du CODE ($E7E6, $0000-$3FFF) est independant de celui de la
* memoire VIDEO ($E7E5, $A000-$DFFF) : monter la page d'une routine de dessin
* ne derange pas le tampon dans lequel elle peint.
*
* Cas de migration : docs/lang/en/migration/paged-routine.md
*
* Entree : A = page a monter, soit map.RAM_OVER_CART+<region>.page
*          X = adresse d'entree de la routine
* Sortie : B ecrase. Tout le reste appartient a la routine appelee.
* ---------------------------------------------------------------------------

paged.call
        _GetCartPageB                  ; la page de l'appelant, a rendre apres
        pshs  b
        _SetCartPageA                  ; monte la page de la routine
        jsr   ,x
        puls  b
        _SetCartPageB                  ; rend sa page a l'appelant
        rts
