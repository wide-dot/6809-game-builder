package com.widedot.m6809.gamebuilder.to8.builder;

import java.io.File;
import java.io.FileInputStream;
import java.io.InputStream;
import java.nio.file.Paths;
import java.util.HashMap;
import java.util.Map;

import org.apache.commons.lang3.StringUtils;

import com.widedot.m6809.gamebuilder.to8.image.PngToBottomUpB16Bin;
import com.widedot.m6809.gamebuilder.to8.ram.RamImage;
import com.widedot.m6809.gamebuilder.to8.storage.FdUtil;
import com.widedot.m6809.gamebuilder.to8.storage.T2Util;
import com.widedot.m6809.gamebuilder.util.OrderedProperties;
import com.widedot.m6809.gamebuilder.util.PropertiesReader;

public class Game {
	
	public String name;
	
	// Engine Loader
	public String engineAsmBootFd;
	public String engineAsmRAMLoaderManagerFd;
	public String engineAsmRAMLoaderFd;
	public static int loadManagerSizeFd = 0;	
	
	public String engineAsmBootT2;
	public String engineAsmRAMLoaderManagerT2;
	public String engineAsmRAMLoaderT2;	
	public static int loadManagerSizeT2 = 0;
	public static int bootSizeT2 = 0;
	public static int T2_NB_PAGES = 128;
	public String engineAsmBootT2Flash;
	public String engineAsmT2Flash;
	
	// Game Mode
	public String gameModeBoot;
	public HashMap<String, GameMode> gameModes = new HashMap<String, GameMode>();
	public static HashMap<String, GameModeCommon> allGameModeCommons = new HashMap<String, GameModeCommon>();	
	public static HashMap<String, Object> allObjects = new HashMap<String, Object>();
	public static HashMap<String, PngToBottomUpB16Bin> allBackgroundImages = new HashMap<String, PngToBottomUpB16Bin>();

	// Build
	public String lwasm;
	public String exobin;
	public String hxcfe;
	public boolean debug;
	public boolean logToConsole;	
	public String outputDiskName;
	public String t2Name;
	public byte[] t2BootData = new byte[27];
	public static String constAnim;
	public static String generatedCodeDirName;
	public static String generatedCodeDirNameDebug;
	public boolean memoryExtension;
	public static int nbMaxPagesRAM;	
	public boolean useCache;
	public int maxTries;
	public static String pragma;
	public static String[] includeDirs;
	public static String define;
	
	// Storage
	public FdUtil fd = new FdUtil();
	public T2Util t2 = new T2Util();	
	public RamImage romT2 = new RamImage(T2_NB_PAGES);
	
	public AsmSourceCode glb;
	
	public byte[] engineRAMLoaderManagerBytesFd;	
	public byte[] engineRAMLoaderManagerBytesT2;	
	public byte[] engineAsmRAMLoaderBytes;	
	public byte[] mainEXOBytes;
	public byte[] bootLoaderBytes;
	
	public Game() throws Exception {	
	}
	
	public Game(String file) throws Exception {	
			OrderedProperties prop = new OrderedProperties();
			this.name = "Game";
			
			try {
				InputStream input = new FileInputStream(file);
				prop.load(input);
			} catch (Exception e) {
				throw new Exception("\tUnable to load: "+file, e); 
			}
			
			
			
			if (prop.getProperty("builder.to8.memoryExtension") == null) {
				throw new Exception("builder.to8.memoryExtension not found in "+file);
			}
			memoryExtension = (prop.getProperty("builder.to8.memoryExtension").contentEquals("Y")?true:false);
			if (memoryExtension) {
				nbMaxPagesRAM = 32;
			} else {
				nbMaxPagesRAM = 16;
			}

			// Engine ASM source code
			// ********************************************************************
			
			PropertiesReader propertiesReader = PropertiesReader.builder().properties(prop).build();
			
			engineAsmBootFd = propertiesReader.get("engine.asm.boot.fd");			
			engineAsmBootT2 = propertiesReader.get("engine.asm.boot.t2");
			engineAsmBootT2Flash = propertiesReader.get("engine.asm.boot.t2flash");							
			engineAsmT2Flash = propertiesReader.get("engine.asm.t2flash");
			engineAsmRAMLoaderManagerFd = propertiesReader.get("engine.asm.RAMLoaderManager.fd");
			engineAsmRAMLoaderFd = propertiesReader.get("engine.asm.RAMLoader.fd");	
			engineAsmRAMLoaderManagerT2 = propertiesReader.get("engine.asm.RAMLoaderManager.t2");				
			engineAsmRAMLoaderT2 = propertiesReader.get("engine.asm.RAMLoader.t2");
			constAnim = propertiesReader.get("builder.constAnim");	
			
			generatedCodeDirName = propertiesReader.get("builder.generatedCode") + "/";
			Paths.get(generatedCodeDirName).toFile().mkdir();		
			
			generatedCodeDirNameDebug = generatedCodeDirName + "/debug/";
			Paths.get(generatedCodeDirNameDebug).toFile().mkdir();

			// Game Definition
			// ********************************************************************		

			gameModeBoot = prop.getProperty("gameModeBoot");
			if (gameModeBoot == null) {
				throw new Exception("gameModeBoot not found in "+file);
			}

			HashMap<String, String[]> gameModeProperties = PropertyList.get(prop, "gameMode");
			if (gameModeProperties == null) {
				throw new Exception("gameMode not found in "+file);
			}
			
			// Chargement des fichiers de configuration des Game Modes
			for (Map.Entry<String,String[]> curGameMode : gameModeProperties.entrySet()) {
				BuildDisk.prelog += ("\tLoad Game Mode "+curGameMode.getKey()+": "+curGameMode.getValue()[0]+"\n");
				gameModes.put(curGameMode.getKey(), new GameMode(curGameMode.getKey(), curGameMode.getValue()[0]));
			}	

			// Build parameters
			// ********************************************************************				

			lwasm = prop.getProperty("builder.lwasm");
			if (lwasm == null) {
				throw new Exception("builder.lwasm not found in "+file);
			}
			
			pragma = prop.getProperty("builder.lwasm.pragma");
			if (pragma != null) {
				pragma = "--pragma=" + pragma;
			} else {
				pragma = "";
			}

			includeDirs = prop.getProperty("builder.lwasm.includeDirs").split(";");
			if (includeDirs != null) {
				for (int i=0; i<includeDirs.length; i++)
					includeDirs[i] = "--includedir=" + includeDirs[i];
			}
			
			define = prop.getProperty("builder.lwasm.define");
			if (define != null) {
				define = "--define=" + define;
			} else {
				define = "";
			}	

			if (prop.getProperty("builder.debug") == null) {
				throw new Exception("builder.debug not found in "+file);
			}
			debug = (prop.getProperty("builder.debug").contentEquals("Y")?true:false);
			
			exobin = prop.getProperty("builder.exobin");
			if (exobin == null) {
				BuildDisk.prelog += ("\nRam Data will be compressed by ZX0\n");
			} else {
				BuildDisk.prelog += ("\nRam Data will be compressed by Exomizer\n");
			}
			
			hxcfe = prop.getProperty("builder.hxcfe");
			if (hxcfe == null) {
				BuildDisk.prelog += ("\nhxcfe not defined.\n");
			}	

			if (prop.getProperty("builder.logToConsole") == null) {
				throw new Exception("builder.logToConsole not found in "+file);
			}
			logToConsole = (prop.getProperty("builder.logToConsole").contentEquals("Y")?true:false);

			t2Name = propertiesReader.get("builder.t2Name").trim();
     		t2Name = StringUtils.left(t2Name, 22); // 22 caractères uniquement, max.
			
			outputDiskName = prop.getProperty("builder.diskName");
			if (outputDiskName == null) {
				throw new Exception("builder.diskName not found in "+file);
			}
			
			Paths.get(outputDiskName).getParent().toFile().mkdir();	

			if (prop.getProperty("builder.compilatedSprite.useCache") == null) {
				throw new Exception("builder.compilatedSprite.useCache not found in "+file);
			}
			useCache = (prop.getProperty("builder.compilatedSprite.useCache").contentEquals("Y")?true:false);

			if (prop.getProperty("builder.compilatedSprite.maxTries") == null) {
				throw new Exception("builder.compilatedSprite.maxTries not found in "+file);
			}
			maxTries = Integer.parseInt(prop.getProperty("builder.compilatedSprite.maxTries"));
			
			glb = new AsmSourceCode(BuildDisk.createFile(FileNames.GAME_GLOBALS, ""));
		}	
}