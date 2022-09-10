package com.widedot.m6809.gamebuilder;

import com.widedot.m6809.gamebuilder.builder.BuildDisk;
import com.widedot.m6809.gamebuilder.builder.Game;
import com.widedot.m6809.gamebuilder.builder.RamLoaderCompiler;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class MainProg
{


	public static Game game;

	/**
	 * Génère une image de disquette dans les formats .fd et .sd pour 
	 * l'ordinateur Thomson TO8.
	 * L'image de disquette contient un secteur d'amorçage et le code
	 * MainGameManager qui sera chargé en mémoire par le code d'amorçage.
	 * Ce programme n'utilise donc pas de système de fichier.
	 * 
	 * Plan d'adressage d'une disquette Thomson TO8 ou format .fd (655360 octets ou 640kiB)
	 * Identifiant des faces: 0-1
	 * Pour chaque face, identifiant des pistes: 0-79
	 * Pour chaque piste, identifiant des secteurs: 1-16
	 * Taille d'un secteur: 256 octets
	 * face=0 piste=0 secteur=1 : octets=0 à 256 (Secteur d'amorçage)
	 * ...
	 * 
	 * Le format .sd (1310720 octets ou 1,25MiB) reprend la même structure que le format .fd mais ajoute
	 * 256 octets à la fin de chaque secteur avec la valeur FF
	 * 
	 * Remarque il est posible dans un fichier .fd ou .sd de concaténer deux disquettes
	 * Cette fonctionnalité n'est pas (encore ;-)) implémentée ici.
	 * 
	 * Mode graphique utilisé: 160x200 (seize couleurs sans contraintes)
	 * 
	 * @param args nom du fichier properties contenant les données de configuration
	 * @throws Throwable 
	 */
	
	public static void main(String[] args) throws Throwable
	{
		try {
			
			Startup.showSplash();
			Startup.createTemporaryDirectory(true);
			Startup.extractResource("/tools.zip", true);
			Startup.extractResource("/engine.zip", false);
			
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
