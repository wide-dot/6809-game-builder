* ===========================================================================
* Objets du stage 02 — genere par tools/gen_objid.py 02
* ===========================================================================
* Les 2 identifiants que la wave reelle du niveau 02 reference, et
* l'index que RunObjects consulte : une page et une adresse par identifiant.
*
* C'est la voie 3 de la frontiere — les deux tables sont EXPORTees par le
* stage, le moteur les tient en EXTERNAL, et le re-link global du chargement
* de scene les repointe a chaque echange. Toutes les entrees visent le meme
* bouchon tant que les ennemis ne sont pas portes ; le chemin exerce, lui,
* est le vrai : wave -> LoadObject_u -> id -> RunObjects -> index -> code.


ObjID_pow                    equ 1
ObjID_bossmusic              equ 2
objid.count                  equ 2
