package com.widedot.m6809.gamebuilder.plugin.floppydisk.storage.configuration;

import java.util.HashMap;

import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.spi.configuration.NodeAttr;
import com.widedot.m6809.gamebuilder.spi.configuration.SourceMap;

public class Storage {
	public String model;
	public Segment segment;
	public Interleave interleave;
	public Fat fat;
	public HashMap<String, Section> sections = new HashMap<String, Section>();

	public Storage(ImmutableNode node, SourceMap sources) throws Exception {
		model = NodeAttr.getString(node, sources, "model");

		segment = new Segment(NodeAttr.child(node, sources, "segment"), sources);
		interleave = new Interleave(NodeAttr.child(node, sources, "interleave"), sources, segment.sectors);
		fat = new Fat(NodeAttr.child(node, sources, "fat"), sources);

		for (ImmutableNode child : node.getChildren()) {
			if ("section".equals(child.getNodeName())) {
				Section section = new Section(child);
				sections.put(section.name, section);
			}
		}
	}
}
