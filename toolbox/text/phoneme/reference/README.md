# Reference material

`openipa/` is a working copy of the OpenIPA project, kept as the reference
for the French grapheme to phoneme rules that were hand ported to Java in
`../src/main/java/com/widedot/toolbox/text/phoneme/`.

It is **not** compiled and **not** packaged: the plugin only reads `fr.json`
and `fr.csv` from `src/main/resources`. It used to live under
`src/main/resources`, which put 8.8 MB of TypeScript sources into the plugin
jar and, more importantly, exposed its `package.json` / `pnpm-lock.yaml` to
the repository dependency scan — those two files accounted for the bulk of
the security alerts raised against this project while none of that code ever
runs here.

Both manifests were therefore removed. Fetch them from upstream if you need
to run the original web application:

    https://github.com/lingorado/openipa
