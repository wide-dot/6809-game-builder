/[readme]/unpack-tools

# Unpack the 6809 game builder tools
## Description
This guide will show how to unpack the game builder tools.

All commands and sample code are Linux based, but the same principles applies to MacOS and Windows platforms.

## Extracting the tools

After building the project, get the right file dependending on your plateform located in `./package/target`

Copy one on the file depending on your plateform into the folder of your choice and run it : a folder `6809-game-builder-tools` will be created with all the tools.

for example : `~/tmp/dev/thomson

```bash
robin:~/tmp/dev/thomson $ cp ~/github/wide-dot/6809-game-builder/package/target/gamebuilder-package .
robin:~/tmp/dev/thomson $ ./gamebuilder-package
    __   ___   ___   ___     _____                        ____        _ _     _           
   / /  / _ \ / _ \ / _ \   / ____|                      |  _ \      (_) |   | |          
  / /_ | (_) | | | | (_) | | |  __  __ _ _ __ ___   ___  | |_) |_   _ _| | __| | ___ _ __ 
 | '_ \ > _ <| | | |\__, | | | |_ |/ _` | '_ ` _ \ / _ \ |  _ <| | | | | |/ _` |/ _ \ '__|
 | (_) | (_) | |_| |  / /  | |__| | (_| | | | | | |  __/ | |_) | |_| | | | (_| |  __/ |   
  \___/ \___/ \___/  /_/    \_____|\__,_|_| |_| |_|\___| |____/ \__,_|_|_|\__,_|\___|_|   
------------------------------------------------------------------------------------------                                                                                          
                                                                                          
10:31:19.616 | INFO  | MainProg > 6809-game-builder - unpack tools
10:31:19.620 | INFO  | Startup > Extracting /tools-core.zip in /home/robin/tmp/dev/thomson
10:31:19.872 | INFO  | Startup > Extracting /tools-linux.zip in /home/robin/tmp/dev/thomson


robin:~/tmp/dev/thomson $ ll
total 31376
drwxrwxr-x 3 robin robin     4096 janv. 17 10:31 ./
drwxrwxr-x 3 robin robin     4096 janv. 17 10:28 ../
drwxrwxr-x 4 robin robin     4096 janv. 17 10:31 6809-game-builder-tools/
-rwxrwxr-x 1 robin robin 32112908 janv. 17 10:30 gamebuilder-package*


robin:~/tmp/dev/thomson $ ll 6809-game-builder-tools/bin
total 656
drwxrwxr-x 2 robin robin   4096 janv. 17 10:31 ./
drwxrwxr-x 4 robin robin   4096 janv. 17 10:31 ../
-rwxrw-r-- 1 robin robin 219344 janv. 17 10:31 exomizer*
-rwxrw-r-- 1 robin robin   5375 janv. 17 10:31 gamebuilder*
-rwxrw-r-- 1 robin robin   5421 janv. 17 10:31 gfxcomp*
-rwxrw-r-- 1 robin robin  23104 janv. 17 10:31 lwar*
-rwxrw-r-- 1 robin robin 242384 janv. 17 10:31 lwasm*
-rwxrw-r-- 1 robin robin  52032 janv. 17 10:31 lwlink*
-rwxrw-r-- 1 robin robin  14408 janv. 17 10:31 lwobjdump*
-rwxrw-r-- 1 robin robin   5416 janv. 17 10:31 png2bin*
-rwxrw-r-- 1 robin robin   5405 janv. 17 10:31 smid*
-rwxrw-r-- 1 robin robin   5424 janv. 17 10:31 stm2bin*
-rwxrw-r-- 1 robin robin   5405 janv. 17 10:31 svgm*
-rwxrw-r-- 1 robin robin  43232 janv. 17 10:31 vgm2smps*
-rwxrw-r-- 1 robin robin   6539 janv. 17 10:31 wddebug*


Then add the `6809-game-builder-tools/bin` directory in your PATH environment variable in order to make them launchable from anywhere.




[readme]: ../readme.md
