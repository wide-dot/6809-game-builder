# .stm file format
## Description
Simple tile map (.stm) file is a Pro Motion NG specific format.

## Format
|Position (bytes)|Type|Description|
|-|-|-|
|$00|4 ASCII-chars|"STMP" as sign for this format|
|$04|Word|Number of horizontal tiles = WIDTH|
|$06|Word|Number of vertical tiles = HEIGHT|
|$08|| 	From this position there are WIDTH * HEIGHT entries made up of the following TileReference structure|

**TileReference structure**
|Position (bytes)|Type|Description|
|-|-|-|
|$00|Word|Tile index|
|$02|Byte|Flag if the tile is to be displayed mirrored horizontally. 0=no mirror|
|$03|Byte|Flag if the tile is to be displayed mirrored vertically. 0=no mirror|

## Limitations

There is no support for hardware image mirroring in the game engine, mirrored tiles are managed in software with dedicated tile ids.

As a result, **tile mirroring** option should be unchecked for both X and Y axis in Pro Motion NG when converting an image to tilemap.
