package com.widedot.m6809.gamebuilder.builder;

import java.util.HashMap;
import java.util.List;

import com.widedot.m6809.gamebuilder.configuration.Media;
import com.widedot.m6809.gamebuilder.configuration.Medium;
import com.widedot.m6809.gamebuilder.configuration.Package;
import com.widedot.m6809.gamebuilder.configuration.Ressource;
import com.widedot.m6809.util.lwasm.Assembler;

public class GameBuilder {

	public GameBuilder(HashMap<String, String> defines, List<Medium> mediumList, String path) throws Exception {
		for (Medium medium : mediumList) {
			for (Media media : medium.mediaList) {
				for (Package pack : media.packList) {
					for (Ressource ressource : pack.fileset.ressources) {
						if (ressource.type == Ressource.ASM_INT) {
							Assembler.process(ressource.file, defines);
						}
					}
				}
			}
		}
	}

	public void build() {
		
	}
	
}
