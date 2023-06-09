package com.widedot.m6809.gamebuilder.builder;

import java.util.HashMap;
import java.util.List;

import com.widedot.m6809.gamebuilder.configuration.Media;
import com.widedot.m6809.gamebuilder.configuration.FileGroup;
import com.widedot.m6809.gamebuilder.configuration.Ressource;
import com.widedot.m6809.util.lwasm.Assembler;

public class GameBuilder {

	public GameBuilder(HashMap<String, String> defines, List<Media> mediaList, String path) throws Exception {
		for (Media media : mediaList) {
			for (FileGroup pack : media.fileGroups) {
				for (Ressource ressource : pack.fileset.ressources) {
					if (ressource.type == Ressource.ASM_INT) {
						Assembler.process(ressource.file, defines);
					}
				}
			}
		}
	}

	public void build() {
		
	}
	
}
