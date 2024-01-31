/[index]/[toolbox]/pcm2dpcm

[index]: ../../../../../readme.md
[toolbox]: ../../../../../docs/toolbox.md

# pcm2dpcm
## Description

pcm2dpcm is a tool from ValleyBell's SMPS research pack

## Features
* lossy audio compression
* convert pcm absolute values (8bits) into differential values (4bits)
* 4bit values are indexes to 8bit values (@DACDecodeTbl in the player assembly code)

## Create RAW audio

Input file must be prepared before conversion.

- open your audio file in audacity (or any audio editing tool)
- set Project Rate (Hz) to 8000 or 16000
- export the file by doing : File > Export > Export audio > Save as type : other uncompressed files > Header : RAW (header-less) > Encoding : Unsigned 8-bit PCM

## Usage
(for Windows users, add .exe to the tool name)

pcm2dpcm -dpcmdata "000408102030406080FCF8F0E0D0C0A0" -aos 2 input.raw output.bin

Notes:
- asm players are available in 8000 or 16000 Hz, but you can make your own version by adjusting waiting times in assembly code
- dpcmdata can be modified as long as it is accordingly changed in the player (@DACDecodeTbl)
- you can use @DACDecodeTbl to downsample to lower bit range by dividing table values, this is actually done in player (6bit samples instead of 8bit)
