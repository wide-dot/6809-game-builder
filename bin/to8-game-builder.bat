@ECHO OFF
IF not defined TO8_GAME_BUILDER_HOME (
    echo Variable TO8_GAME_BUILDER_HOME is unset.
    echo Please set this variable into your environment.
    exit
)

set JAR_NAME=to8-game-builder
set JAR_VERSION=0.0.2-SNAPSHOT

java -jar %TO8_GAME_BUILDER_HOME%/target/%JAR_NAME%-%JAR_VERSION%-jar-with-dependencies.jar %*
