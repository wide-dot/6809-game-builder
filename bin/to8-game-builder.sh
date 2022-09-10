#!/bin/bash

if [ -z ${TO8_GAME_BUILDER_HOME+x} ]; then 
    echo "Variable TO8_GAME_BUILDER_HOME is unset." 
    echo "Please set this variable into your environment."
    exit 1 
fi

JAR_NAME=to8-game-builder
JAR_VERSION=0.0.2-SNAPSHOT

java -jar $TO8_GAME_BUILDER_HOME/target/$JAR_NAME-$JAR_VERSION-jar-with-dependencies.jar $1