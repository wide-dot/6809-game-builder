package com.widedot.m6809.newgamebuilder.to8;

import com.widedot.m6809.newgamebuilder.to8.builder.Builder;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class MainProg
{
	public static void main(String[] args) throws Throwable
	{
		try {
			
			Startup.showSplash();
		
			Config.loadGameConfiguration(args[0]);			
			Startup.clean();
			Builder.init();
			
		} catch (Exception e) {
			log.error("Build error : {}", e);
		}
	}

}
