package com.widedot.m6809.gamebuilder.to8;

import com.widedot.m6809.gamebuilder.to8.builder.BuildDisk;
import com.widedot.m6809.gamebuilder.to8.builder.Game;
import com.widedot.m6809.gamebuilder.to8.builder.RamLoaderCompiler;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class MainProg
{
	public static Game game;

	public static void main(String[] args) throws Throwable
	{
		try {
			
			Startup.showSplash();
		
			Config.loadGameConfiguration(args[0]);
			
			log.info("T2 Name : {}", game.t2Name);
			
			Startup.clean();
			
			BuildDisk.initT2();
			log.info("T2 Raw $0000 Data : {}", game.t2BootData);
			
			RamLoaderCompiler.compileRAMLoader();
			BuildDisk.generateObjectIDs();
			BuildDisk.generateGameModeIDs();
			BuildDisk.processSounds();			
			BuildDisk.processBackgroundImages();
			BuildDisk.generateSprites();
			BuildDisk.generateTilesets();
			BuildDisk.compileMainEngines(false);
			BuildDisk.compileObjects();
			
			System.gc();
			
			BuildDisk.computeRamAddress();
			BuildDisk.computeRomAddress();
			BuildDisk.generateDynamicContent();
			BuildDisk.generateImgAniIndex();
			BuildDisk.applyDynamicContent();		
			BuildDisk.compileMainEngines(true);
            BuildDisk.applyDynamicContent();
			BuildDisk.compressData();
			BuildDisk.writeObjectsFd(); 
			BuildDisk.writeObjectsT2();
			BuildDisk.compileRAMLoaderManager();
			BuildDisk.compileAndWriteBootFd();
			BuildDisk.compileAndWriteBootT2();
			BuildDisk.buildT2Flash();
			
		} catch (Exception e) {
			log.error("Build error : {}", e);
		}
	}

}
