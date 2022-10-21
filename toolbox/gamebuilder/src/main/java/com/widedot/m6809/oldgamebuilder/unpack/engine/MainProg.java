package com.widedot.m6809.oldgamebuilder.unpack.engine;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class MainProg
{

	public static void main(String[] args) throws Throwable
	{
		
		// gmb.bat -e --engine         // dezip du fichier engine, ne pas faire si repertoire déjà présent
		// gmb.bat                     // traite toutes les target de tous les fichiers xml trouvés dans le répertoire (avec <gamebuilder> en tag de plus haut niveau) 
		// gmb.bat -f=config.xml       // traite toutes les target du fichier
		// gmb.bat -t=fd               // traite tous les fichiers .xml avec target fd
		// gmb.bat -f=config.xml -t=fd // traite le fichier .xml avec target fd
		// gmb.bat -d=mondir           // traite tous les fichiers .xml du dir
		// gmb.bat -d=mondir -t=fd     // traite tous les fichiers .xml du dir avec target fd
		
		
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
