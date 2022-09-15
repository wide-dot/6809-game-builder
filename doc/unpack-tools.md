# Unpack the 6809 game builder tools
## Description
This guide will show how to unpack the game builder tools.

All commands and sample code are Windows based, but the same principles applies to macOS and Linux platforms.

## Setup a directory
Create a directory that will hold the 6809 game engine tools.
Move the downloaded .jar file in that directory.

    C:\Users\Public\Documents\6809-game-builder
    |___ gamebuilder-package-0.0.1-jar-with-dependencies.jar

## Execute the jar
Double click on the jar, or run this command :

    C:\Users\Public\Documents\6809-game-builder>java -jar gamebuilder-package-0.0.1-jar-with-dependencies.jar

This will extract all tools in a subdirectory called 6809-game-builder-tools

        __   ___   ___   ___     _____                        ____        _ _     _
       / /  / _ \ / _ \ / _ \   / ____|                      |  _ \      (_) |   | |
      / /_ | (_) | | | | (_) | | |  __  __ _ _ __ ___   ___  | |_) |_   _ _| | __| | ___ _ __
     | '_ \ > _ <| | | |\__, | | | |_ |/ _` | '_ ` _ \ / _ \ |  _ <| | | | | |/ _` |/ _ \ '__|
     | (_) | (_) | |_| |  / /  | |__| | (_| | | | | | |  __/ | |_) | |_| | | | (_| |  __/ |
      \___/ \___/ \___/  /_/    \_____|\__,_|_| |_| |_|\___| |____/ \__,_|_|_|\__,_|\___|_|
    ------------------------------------------------------------------------------------------
    
    09:02:32.961 [main] INFO com.widedot.m6809.gamebuilder.unpack.tools.Startup - Extracting /    tools-core.zip in C:\Users\Public\Documents\6809-game-builder
    09:02:33.036 [main] INFO com.widedot.m6809.gamebuilder.unpack.tools.Startup - Extracting /    tools-win.zip in C:\Users\Public\Documents\6809-game-builder

You should now have this directory structure :

    C:\Users\Public\Documents\6809-game-builder
    |___ 6809-game-builder-tools
         |___ bin  (launch scripts for java tools and native tools)
         |___ repo (java binaries)

Note : The native tools to unpack will be chosen based on the acutal runtime platform.

## Update your PATH

Add the bin directory to your PATH.
Needless to say, this will allow running all 6809 game builder tools anywhere in your system.





