package com.widedot.m6809.gamebuilder;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class MainProg
{
	public static void main(String[] args) throws Throwable
	{
		try {
			
			Startup.showSplash();
			Startup.extractResource("/tools.zip", true);

		} catch (Exception e) {
			log.error("Error : {}", e);
		}
	}
}
