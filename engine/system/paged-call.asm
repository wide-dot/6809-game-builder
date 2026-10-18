* ---------------------------------------------------------------------------
* paged.call
* ----------
* Calls a routine living in a RAM page, from resident code.
*
* The v2 counterpart of what v1 got by declaring an object, whose only use
* was to have its code placed in a RAM bank and its page mounted before the
* call. In v2 both come otherwise, without indirection :
*
*   - the PAGE is an assembly constant : a layout <region> gives the equate
*     <region>.page, a <direntry> exports <name>$PAGE resolved at load ; the
*     caller writes the page as an immediate.
*   - the ADDRESS is a link symbol : the unit EXPORTs its entry, the scene
*     load's re-link points it.
*
* An object goes through Obj_Index_* because a wave names it by its id at
* run time ; a routine known at assembly has nothing to do in that index.
*
* Unlike RunPgSubRoutine, no self-modified operand : the caller's page lives
* on the stack, so the call is reentrant. The code window ($E7E6,
* $0000-$3FFF) is independent of the video one ($E7E5, $A000-$DFFF) :
* mounting a drawing routine's page leaves the buffer it draws into alone.
*
* Migration case : docs/lang/en/migration/paged-routine.md
*
* In  : A the page to mount, map.RAM_OVER_CART+<region>.page
*       X the routine's entry
* Out : B trashed ; the rest is the routine's.
* ---------------------------------------------------------------------------

paged.call
        _GetCartPageB                  ; the caller's page, given back after
        pshs  b
        _SetCartPageA                  ; the routine's
        jsr   ,x
        puls  b
        _SetCartPageB
        rts
