/[index]/[toolbox]/pcm

[index]: ../../../../readme.md
[toolbox]: ../../../../docs/toolbox.md

# pcm
## Description
Toolbox for pcm binary data.
## Features
* convert 8bit samples to 6bit, bytes are padded

## Usage

(for Windows users, add .bat to the script name)

    pcm (-d=Input   directory | -f=Input file)

    Toolbox for pcm binary data
        -f,    --filename=Input file or directory  (Process an .raw input file, or all .raw files in a directory and produce .bin files)
        -8to6, --8to6bit                           (While keeping 8byte for each sample, will downscale sample value to 6bit)

### Examples

Convert all .raw files in current directory :

    pcm -d=./ -8to6

Convert the sample kick.raw :

    pcm -f=kick.raw -8to6

## Sample Test
### Input
kick.raw

    7F 7F 7F 81 7E 7F 90 7A 7A 7E 7E ...


### Command

    pcm -f=kick.raw

### Output
kick.6bit.bin

    1F 1F 1F 20 1F 1F 24 1E 1E 1F 1F ...
