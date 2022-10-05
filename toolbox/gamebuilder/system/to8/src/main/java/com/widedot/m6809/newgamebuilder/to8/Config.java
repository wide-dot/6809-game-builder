package com.widedot.m6809.newgamebuilder.to8;

import org.slf4j.LoggerFactory;

import ch.qos.logback.classic.Level;
import ch.qos.logback.classic.Logger;
import lombok.extern.slf4j.Slf4j;

@Slf4j
public class Config
{

	public static void loadGameConfiguration(String configFileName) throws Exception {
		log.info("Loading configuration : {} ...",configFileName);
		
		// logger init
		Logger root = (Logger)LoggerFactory.getLogger(org.slf4j.Logger.ROOT_LOGGER_NAME);
		root.setLevel(Level.DEBUG);

	}

}
