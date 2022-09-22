# Package: relocatable

    <package id="0" type="relocatable" compression="zx0">
        <asm>src/data/code.asm</asm>
        <bin>src/data/data.bin</bin>
    </package>

## Runtime usage

If the relocatable package is loaded in a commutable memory :

            lda   #1     ; package id
            ldb   #4     ; page id
            ldx   #$1000 ; address
            jsr   LoadRelocatablePackage

If the relocatable package is loaded in the non-commutable memory :

            lda   #2     ; package id
            ldx   #$8000 ; address
            jsr   LoadRelocatablePackage_nc

