# Package: absolute

    <package id="0" type="absolute" compression="zx0" org="$6100">
        <asm>src/hello-world/main.asm</asm>
    </package>

## Runtime usage
If the relocatable package is loaded in a commutable memory :

            lda   #1     ; package id
            ldb   #4     ; page id
            jsr   LoadAbsolutePackage

If the relocatable package is loaded in the non-commutable memory :

            lda   #2     ; package id
            jsr   LoadAbsolutePackage_nc

