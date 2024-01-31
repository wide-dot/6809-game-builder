# png2pal
## Description
Convert an image file (.png) to palette data in an assembly file (.asm).
## Features
* handle png PLTE chunk (1, 2, 4, 8 bit depths)
* encode palette data based on external profiles
* use CIE lab space for conversion

## Usage
### Plugin

### Command line
(for Windows users, add .bat to the script name)

    png2pal [-s=Symbol name] [-b=Color bit depth] [-o=Color index offset] [-p=Profile name] (-d=Input directory | -f=Input file) [-g=Output name]

    image to palette converter
        -s, --symbol=Symbol name in asm (default to filename)
        -b, --bitdepth=Color bit depth, determines the number of converted colors (default to png bitdepth)
        -o, --offset=Color index offset, determines the starting color index (default to 1, index 0 is gennarally assigned to transparent color)
        -p, --profile=Color profile (to (default))
        -d, --dir=Input directory (will take only .png files)
        -f, --file=Input png file
        -g, --gensource=Output asm file name (default to input filename with .asm ext)


