package com.widedot.m6809.gamebuilder;


import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.core.LoggerContext;
import org.apache.logging.log4j.core.config.Configuration;
import org.apache.logging.log4j.core.config.LoggerConfig;
import org.slf4j.LoggerFactory;

import com.widedot.m6809.gamebuilder.builder.Game;

import ch.qos.logback.classic.Level;
import ch.qos.logback.classic.Logger;
import lombok.extern.slf4j.Slf4j;

@Slf4j
public class Config
{

	public static void loadGameConfiguration(String configFileName) throws Exception {
		log.info("Loading Game configuration : {} ...",configFileName);
		MainProg.game = new Game(configFileName);
		
		
		// Initialisation du logger
		if (MainProg.game.debug) {
			Logger root = (Logger)LoggerFactory.getLogger(org.slf4j.Logger.ROOT_LOGGER_NAME);
			root.setLevel(Level.DEBUG);
		}
	
		/*
		LoggerContext context = LoggerContext.getContext(false);
		Configuration configuration = context.getConfiguration();
		LoggerConfig loggerConfig = configuration.getLoggerConfig(LogManager.getRootLogger().getName());
	
		if (!BuildDisk.game.logToConsole) {
			loggerConfig.removeAppender("LogToConsole");
			context.updateLoggers();
		}			
		
		log.debug(BuildDisk.prelog);
		*/

	}

}
