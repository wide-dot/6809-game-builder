/[index]/toolbox

[index]: ../readme.md

# Toolbox

The Toolbox is a collection of plugins provided for the builder. It's possible to add a custom plugin, by following this [procedure][plugin-add].

[plugin-add]: ./plugin-add.md

Here you will find all tools provided by the game engine :

|command|description|in|out|
|-|-|-|-|
|[stm2bin][stm2bin]|convert Tilemaps produced by Pro Motion NG (Cosmigo) into usable assembly data and code|.stm|.bin, .equ|
|[png2bin][png2bin]|image to binary converter|.png|.bin|
|[png2pal][png2pal]|image to palette converter|.png|.asm, .bin|
|[leanscroll][leanscroll]|lean a tilemap for diff scrolling|.raw|.bin|
|[vgm2ymm][vgm2ymm]|vgm to binary converter|.vgm, .vgz|.ymm|
|[vgm2sfx][vgm2sfx]|vgm to sound fx asm converter|.vgm, .vgz|.asm|
|[vgm2vgc][vgm2vgc]|vgm to binary converter|.vgm, .vgz|.vgc|
|[pcm2dpcm][pcm2dpcm]|**TODO change to a plugin** - lossy pcm audio compression|.raw|.bin|

[stm2bin]: ../toolbox/graphics/tilemap/stm/readme.md
[png2bin]: ../toolbox/graphics/png2bin/readme.md
[png2pal]: ../toolbox/graphics/png2pal/readme.md
[leanscroll]: ../toolbox/graphics/tilemap/leanscroll/readme.md
[pcm2dpcm]: ../toolbox/third-party/src/audio/dpcm/readme.md
[vgm2ymm]: ../toolbox/audio/vgm2ymm/readme.md
[vgm2sfx]: ../toolbox/audio/vgm2sfx/readme.md
[vgm2vgc]: ../toolbox/audio/vgm2vgc/readme.md