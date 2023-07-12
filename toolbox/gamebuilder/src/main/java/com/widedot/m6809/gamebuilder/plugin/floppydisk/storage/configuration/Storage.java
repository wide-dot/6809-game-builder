package com.widedot.m6809.gamebuilder.plugin.floppydisk.storage.configuration;

import java.util.HashMap;
import java.util.List;

import org.apache.commons.configuration2.HierarchicalConfiguration;
import org.apache.commons.configuration2.tree.ImmutableNode;

public class Storage {
	public String model;
	public Segment segment;
	public Interleave interleave;
	public Fat fat;
	public HashMap<String, Section> sections = new HashMap<String, Section>();
	
	public Storage(HierarchicalConfiguration<ImmutableNode> node) throws Exception {
		model = node.getString("[@model]", null);
		if (model == null) {
			throw new Exception("model is missing for floppydisk storage");
		}
		
	    List<HierarchicalConfiguration<ImmutableNode>> segmentNodes = node.configurationsAt("segment");
	    if (segmentNodes.size()==0) {
	    	throw new Exception("Segment is mandatory for storage.");
	    }
	    if (segmentNodes.size()>1) {
	    	throw new Exception("Only one segment allowed for storage.");
	    }
	    HierarchicalConfiguration<ImmutableNode> segmentNode = segmentNodes.get(0);
	    segment = new Segment(segmentNode);
		
   	    List<HierarchicalConfiguration<ImmutableNode>> interleaveNodes = node.configurationsAt("interleave");
	    if (interleaveNodes.size()==0) {
	    	throw new Exception("interleave is mandatory for storage.");
	    }
	    if (interleaveNodes.size()>1) {
	    	throw new Exception("Only one interleave allowed for storage.");
	    }
	    HierarchicalConfiguration<ImmutableNode> interleaveNode = interleaveNodes.get(0);
		interleave = new Interleave(interleaveNode);
       	
   	    List<HierarchicalConfiguration<ImmutableNode>> fatNodes = node.configurationsAt("fat");
	    if (fatNodes.size()==0) {
	    	throw new Exception("fat is mandatory for storage.");
	    }
	    if (fatNodes.size()>1) {
	    	throw new Exception("Only one fat allowed for storage.");
	    }
	    HierarchicalConfiguration<ImmutableNode> fatNode = fatNodes.get(0);
       	fat = new Fat(fatNode);
		
	    List<HierarchicalConfiguration<ImmutableNode>> sectionNodes = node.configurationsAt("section");
    	for(HierarchicalConfiguration<ImmutableNode> sectionNode : sectionNodes)
    	{	
    		Section section = new Section(sectionNode);
    	    sections.put(section.name, section);
    	}
	}
}
