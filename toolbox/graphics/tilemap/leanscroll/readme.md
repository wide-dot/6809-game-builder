# leanscroll
## Description
Parse an image or a tilemap and build a lean tilset and map.
When a scroll is made, some pixels on screen do not change, this tool remove any repetitive pixels in a tilemap, taking in account some scroll parameters.
It produces an output tileset with the dedicated map.

This tool also provides a way to build an image from a tilemap and vice versa without any transformation.

## Features
* read a map as:
    - a png image
    - a csv map and a tileset
    - a bin map and a tileset
* apply a lean scroll process (optional) and produce a common image that hold deleted pixels (used for screen initilisation before scroll start)
* save the rendered map, with or without the lean process (optional)
* produce a binary map and a tileset with tiles of an choosen size (optional)
* produce a shifted version of the map and tileset (optional)
* outputs tileset properties to log : nb of tiles, tileset width, tileset height

## Usage

(for Windows users, add .bat to the script name)

```
leanscroll 

; input as an image

           -image=<file>       ; png file (indexed color: 0 transp. 1-16 colors)

; or input as a tileset

           -tileset=<file>     ; png file (indexed color: 0 transp. 1-16 colors)
           -tilesetwidth=<int> ; number of tiles in a tilset row
           -tilewidth=<int>    ; tile width in pixel
           -tileheight=<int>   ; tile height in pixel

        ; tilemap as csv

           -csv=<file>         ; csv file (comma separator, tile index 0-n, 0: transparent tile)

        ; or tilemap as binary

           -tilemap=<file>     ; binary file (tile index)
           -mapwidth=<int>     ; number of tiles in a map row
           -mapbitdepth=<int>  ; nb of bits for a tile index
           [-bigendian]        ; (optional) big endian byte order (default little endian)

; output image

           [-outimage=<file>]  ; (optional) full map image in png

; output tilesets and tilemaps

           [-outtileset=<file>    ; (optional) output tileset in png
            -outtilemap=<file>]   ; (optional) output map in binary

           [-outtileset1=<file>   ; (optional) output tileset in png, X(1) shifted
            -outtilemap1=<file>]  ; (optional) output map in binary for X(1) shifted tiles

           [-outtilewidth=<int>]  ; (optional) ouput tile width (default input tile width)
           [-outtileheight=<int>] ; (optional) ouput tile height (default input tile height)

           [-outmaxsize=<int>]    ; (optional) split map files over n bytes (default no split)

; lean processing

           [-scrollstep=<int,int,int,int,int,int,int,int> ; (optional) scroll step in pixel for : up, down, left, right, upleft, upright, downleft, downright directions
            -nbsteps=<int,int,int,int,int,int,int,int>] ; (optional) number of maximum scroll steps in one frame (used for variable scroll speed) for each directions
           [-multidir] ; multidirectional scroll (needs scrollstep for up, down , left and right directions)
           [-interlace=<int>] ; (optional) erase even (0) or odd (1) lines
           [-leanCsize=<int,int,int,int>] ; common image crop parameters : x, y, width, height
           [-lean=<file>]   ; (optional) full map image lean in png
           [-leanC=<file>]  ; (optional) full map image lean common in png
           [-leanS=<file>]  ; (optional) full map image lean shifted in png
           [-leanCS=<file>] ; (optional) full map image lean common shifted in png
```

### Example

```
leanscroll

-csv=<path>/r-type/objects/levels/01/map/map.csv
-tileset=<path>/r-type/objects/levels/01/map/tileset.png
-tilewidth=28
-tileheight=14
-tilesetwidth=1
-outtileset=<path>/r-type/objects/levels/01/map/0/0.png
-outtilemap=<path>/r-type/objects/levels/01/map/0/0.bin
-outtileset1=<path>r-type/objects/levels/01/map/1/1.png
-outtilemap1=<path>/r-type/objects/levels/01/map/1/1.bin
-scrollstep=0,0,2,0,0,0,0,0
-nbsteps=0,0,1,0,0,0,0,0
-lean=<path>/r-type/objects/levels/01/map/0/fullLean.png
-leanC=<path>/r-type/objects/levels/01/map/init.png
-leanS=<path>/r-type/objects/levels/01/map/1/fullLean.png
-leanCsize=0,0,140,168
-outtilewidth=14
-outtileheight=14
```