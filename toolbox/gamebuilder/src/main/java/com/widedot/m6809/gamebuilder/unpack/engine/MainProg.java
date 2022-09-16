package com.widedot.m6809.gamebuilder.unpack.engine;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class MainProg
{

	public static void main(String[] args) throws Throwable
	{
		try {
			
			Startup.showSplash();
			log.info("6809-game-builder - initialize an empty project for generic 6809 system");
			
			if (args.length !=1 || args[0] == null || args[0].equals("")) {
				log.info("Usage :");
				log.info("Linux/macOS : gmb directory_name");
				log.info("Windows : gmb.bat directory_name");
				return;
			}
			
			if (Startup.createProjectDirectory(args[0])) {
				Startup.extractResource("/engine.zip", false);
			}

			
		} catch (Exception e) {
			log.error("Build error : {}", e);
		}
	}

}
