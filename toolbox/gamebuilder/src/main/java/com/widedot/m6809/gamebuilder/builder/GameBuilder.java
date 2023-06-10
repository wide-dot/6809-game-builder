package com.widedot.m6809.gamebuilder.builder;

import java.util.Arrays;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;

import com.widedot.m6809.gamebuilder.configuration.Media;
import com.widedot.m6809.gamebuilder.configuration.FileGroup;
import com.widedot.m6809.gamebuilder.configuration.Ressource;
import com.widedot.m6809.gamebuilder.configuration.TableOfContent;
import com.widedot.m6809.gamebuilder.lwtools.LwAsm;
import com.widedot.m6809.gamebuilder.lwtools.LwObj;
import com.widedot.m6809.gamebuilder.lwtools.struct.Section;
import com.widedot.m6809.gamebuilder.zx0.Compressor;
import com.widedot.m6809.gamebuilder.zx0.Optimizer;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class GameBuilder {

	public GameBuilder(HashMap<String, String> defines, List<Media> mediaList, String path) throws Exception {
		for (Media media : mediaList) {
			
			// build filegroups that are outside of tables of content
			for (TableOfContent tocs : media.tablesOfContent) {
				for (FileGroup fgs : tocs.fileGroups) {
					
					List<LwObj> objLst = new ArrayList<LwObj>();
					int dataSize = 0;
					for (Ressource ressource : fgs.fileset.ressources) {
						if (ressource.type == Ressource.ASM_INT) {
							LwObj obj = LwAsm.makeObject(ressource.file, path, defines);
							objLst.add(obj);
							for (Section section : obj.secLst) {
								dataSize += section.code.length;
							}
						}
					}
					
					// concat all sections for this filegroup
					log.debug("concat sections");
					byte[] data = new byte[dataSize];
					int j=0;
					for (LwObj obj : objLst) {
						for (Section section : obj.secLst) {
							for (int i=0; i<section.code.length; i++) {
								data[j++] = section.code[i++];
							}
						}
					}

					// compress data
					if (!fgs.codec.equals(FileGroup.NO_CODEC)) {
						log.debug("compress");
						byte[] output = null;
				        int[] delta = { 0 };
				        output = new Compressor().compress(new Optimizer().optimize(data, 0, 32640, 4, false), data, 0, false, false, delta);
				        log.debug("Original size: {}, Packed size: {}, Delta: {}", data.length, output.length, Arrays.toString(delta));
				        if (data.length <= output.length) {
				        	throw new Exception("filegroup compressed data is greater or equal to uncompressed data, you MUST change codec attribute to none. Filegroup name: "+fgs.name);
				        }
				        data = output;
					}
					
					// write do media
					// add to toc
				}
			}
			
			// build filegroups that are outside of tables of content
			for (FileGroup fgs : media.fileGroups) {
				for (Ressource ressource : fgs.fileset.ressources) {
					if (ressource.type == Ressource.ASM_INT) {
						LwAsm.makeBinary(ressource.file, path, defines);
					}
				}
			}
		}
	}

	public void build() {
		
	}
	
}
