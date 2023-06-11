package com.widedot.m6809.gamebuilder.configuration;

import java.util.HashMap;
import java.util.List;

import org.apache.commons.configuration2.HierarchicalConfiguration;
import org.apache.commons.configuration2.tree.ImmutableNode;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class Storage {
	public String name;
	public String type;
	public String ext;
	
	public int faces;
	public int tracks;
	public int sectors;
	public int sectorSize;
	public Interleave interleave;
	
	public HashMap<String, Section> sections = new HashMap<String, Section>();
	
	public Storage(HierarchicalConfiguration<ImmutableNode> node, HashMap<String, Interleave> interleaves) throws Exception {
		name = node.getString("[@name]", null);
		if (name == null) {
			throw new Exception("name is missing for storage");
		}
		
		type = node.getString("[@type]", null);
		if (type == null) {
			throw new Exception("type is missing for storage");
		}
		
		ext = node.getString("[@ext]", null);
		if (ext == null) {
			throw new Exception("ext is missing for storage");
		}
		
		if (type.equals("floppydisk")) {
		    List<HierarchicalConfiguration<ImmutableNode>> segmentNodes = node.configurationsAt("segment");
		    if (segmentNodes.size()==0) {
		    	throw new Exception("Segment is mandatory for storage.");
		    }
		    if (segmentNodes.size()>1) {
		    	throw new Exception("Only one segment allowed for storage.");
		    }
		    
		    HierarchicalConfiguration<ImmutableNode> segmentNode = segmentNodes.get(0);
	
			faces = segmentNode.getInteger("[@faces]", 0);
			if (faces == 0) {
				throw new Exception("faces is missing for segment");
			}
			
			tracks = segmentNode.getInteger("[@tracks]", 0);
			if (tracks == 0) {
				throw new Exception("tracks is missing for segment");
			}
			
			sectors = segmentNode.getInteger("[@sectors]", 0);
			if (sectors == 0) {
				throw new Exception("sectors is missing for segment");
			}
		    
			sectorSize = segmentNode.getInteger("[@sectorSize]", 0);
			if (sectors == 0) {
				throw new Exception("sectorSize is missing for segment");
			}
			
			String interleaveName = segmentNode.getString("[@interleave]", null);
			if (interleaveName == null) {
				interleave = new Interleave(sectors); 
			} else {
				interleave = interleaves.get(interleaveName);
			}
			
		    List<HierarchicalConfiguration<ImmutableNode>> sectionNodes = node.configurationsAt("section");
	    	for(HierarchicalConfiguration<ImmutableNode> sectionNode : sectionNodes)
	    	{	
	    		Section section = new Section();
	    		
	    		section.name = sectionNode.getString("[@name]", null);
	    		if (name == null) {
	    			throw new Exception("name is missing for section");
	    		}
	
	    		section.face = sectionNode.getInteger("[@face]", 0);
	    		if (section.face == 0) {
	    			throw new Exception("face is missing for section");
	    		}
	    		
	    		section.track = sectionNode.getInteger("[@track]", 0);
	    		if (section.track == 0) {
	    			throw new Exception("track is missing for section");
	    		}
	    		
	    		section.sector = sectionNode.getInteger("[@sector]", 0);
	    		if (section.sector == 0) {
	    			throw new Exception("sector is missing for section");
	    		}
	    		
	    	    sections.put(section.name, section);
	    	}
		}
	}
}
