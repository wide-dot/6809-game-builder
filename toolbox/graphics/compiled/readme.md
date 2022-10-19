# gfxcomp
## Description
Compiled/Compressed image generator.

## Features
* mirror images
* shift images by n pixels
* encode to specific video memory layout
* produce an index to image variants
* generate optimized assembly code
* multiple encoding (compiled or compressed)

## Usage

(for Windows users, add .bat to the script name)

    gfxcomp -f=configuration file [-v]

    simple tile map to binary converter
        -f, --file=configuration file
        -v, --verbose

 ## Configuration file

The configuration file is an xml, with a modular structure.

A configuration can hold one or more process tags.

**process**
- dirOut: output directory for generated asm

A process should contain a single memory tag that defines video memory structure :

**memory**
- linearBits: number of bits that defines a pixel in a plane
- planarBits: number of bits to process before going next plane
- LineBytes: number of bytes that defines a line in a plane
- nbPlanes: number of memory planes

A process also contains images, several syntaxes are allowed.

Single image configuration:

    <configuration>
        <process dirOut="asm/sega/image">
            <memory linearBits="4" planarBits="8" lineBytes="40" nbPlanes="2"/>
            <image name="img_sega_sonic_11" file="resources/png/Sonic_045_01.png>
                <encoder name="draw"/>
                <encoder name="draw" mirror="x"/>
            </image>
        </process>
    </configuration>

Multiple images configuration:

    <configuration>
        <process dirOut="asm/sega/image">
            <memory linearBits="4" planarBits="8" lineBytes="40" nbPlanes="2"/>
                <images>
                    <encoder name="draw"/>
                    <encoder name="draw" mirror="x"/>
                    <image name="img_sega_trails_1" file="resources/png/Trails_01.png"/>
                    <image name="img_sega_trails_2" file="resources/png/Trails_02.png"/>
                </images>
        </process>
    </configuration>

One or more encoders are associated at image or images level.
Each encoder declaration will run a encoding process for the image or group of images.

**image**
- name: name that will be used to define the image asm symbol, it should be compliant with lwasm syntax
- file: png file encoded in 8bit color indexed mode, index 0 is for transparency

**encoder**
- name: encoding type (**draw**, bdraw, rle, zx0)
- mirror: pre process image by mirroring it (**none**, x, y, xy)
- shift: pre process image by shifting n pixels to the right (**0**, 1, 2, 3, 4, 5, 6, 7)
- position: image coordinate (**center**, top-left, 3qtr-center)

Default value are in bold.

Note : you can mix encoder definition at images level and image level.

Image or images can be grouped in an imageset. An imageset is an index to image variants.

**imageset**
- fileOut : the name of asm file to generate

Here a sample of a configuration file :

    <configuration>
        <process dirOut="asm/sega/image">
            <memory linearBits="4" planarBits="8" lineBytes="40" nbPlanes="2"/>
            <imageset fileOut="asm/sega/imageset.asm">
                <images>
                    <encoder name="bdraw"/>
                    <encoder name="bdraw" mirror="x"/>
                    <image name="img_sega_sonic_11" file="resources/png/Sonic_045_01.png"/>
                    <image name="img_sega_sonic_12" file="resources/png/Sonic_045_02.png"/>
                    <image name="img_sega_sonic_13" file="resources/png/Sonic_045_03.png"/>
                    <image name="img_sega_sonic_21" file="resources/png/Sonic_046_01.png"/>
                    <image name="img_sega_sonic_22" file="resources/png/Sonic_046_02.png"/>
                    <image name="img_sega_sonic_23" file="resources/png/Sonic_046_03.png"/>
                    <image name="img_sega_sonic_31" file="resources/png/Sonic_047_01.png"/>
                    <image name="img_sega_sonic_32" file="resources/png/Sonic_047_02.png"/>
                    <image name="img_sega_sonic_33" file="resources/png/Sonic_047_03.png"/>
                    <image name="img_sega_sonic_41" file="resources/png/Sonic_048_01.png"/>
                    <image name="img_sega_sonic_42" file="resources/png/Sonic_048_02.png"/>
                    <image name="img_sega_sonic_43" file="resources/png/Sonic_048_03.png"/>
                </images>
                
                <images>
                    <encoder name="draw"/>
                    <encoder name="draw" mirror="x"/>
                    <image name="img_sega_trails_1" file="resources/png/Trails_01.png"/>
                    <image name="img_sega_trails_2" file="resources/png/Trails_02.png"/>
                </images>
    
                <images>
                    <encoder name="draw" mirror="x"/>
                    <image name="img_sega_trails_5" file="resources/png/Trails_05.png"/>
                    <image name="img_sega_trails_6" file="resources/png/Trails_06.png"/>
                </images>
                
                <images>
                    <encoder name="draw" shift="1"/>
                    <image name="img_sega_trails_3" file="resources/png/Trails_03.png"/>
                    <image name="img_sega_trails_4" file="resources/png/Trails_04.png"/>
                    <image name="img_sega_logo_1"   file="resources/png/SEGA_01.png"/>
                    <image name="img_sega_logo_2"   file="resources/png/SEGA_02.png"/>
                </images>
            </imageset>
        </process>
    </configuration>