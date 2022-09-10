@ECHO OFF
IF not defined 6809_GAME_BUILDER_HOME (
    echo Variable 6809_GAME_BUILDER_HOME is unset.
    echo Please set this variable into your environment.
    exit
)

set JAR_NAME=6809-game-builder
set JAR_VERSION=0.0.2-SNAPSHOT

java -cp %6809_GAME_BUILDER_HOME%/target/%JAR_NAME%-%JAR_VERSION%-jar-with-dependencies.jar %*
