package com.widedot.m6809.gamebuilder.unpack.tools;

import com.widedot.m6809.util.OSValidator;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class MainProg
{
	public static void main(String[] args) throws Throwable
	{
		try {
			
			Startup.showSplash();
			log.info("6809-game-builder - unpack tools");
			
			Startup.extractResource("/tools-core.zip", true);
			if (OSValidator.IS_WINDOWS) {
				Startup.extractResource("/tools-win.zip", true);
			} else if (OSValidator.IS_MAC) {
				Startup.extractResource("/tools-macos.zip", true);
			} else if (OSValidator.IS_UNIX) {
				Startup.extractResource("/tools-linux.zip", true);
			}
			
		} catch (Exception e) {
			log.error("Error : {}", e);
		}
	}
}
