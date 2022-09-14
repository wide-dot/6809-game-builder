package com.widedot.m6809.gamebuilder;

import com.widedot.m6809.gamebuilder.util.OSValidator;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class MainProg
{
	public static void main(String[] args) throws Throwable
	{
		try {
			
			Startup.showSplash();
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
