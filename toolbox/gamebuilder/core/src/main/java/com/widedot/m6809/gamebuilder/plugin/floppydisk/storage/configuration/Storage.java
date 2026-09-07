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

	/**
	 * A target may override the storage's interleave on its {@code <floppydisk>}
	 * (softskip, softskew, hardskip) : the same media model, another sector
	 * order — two images to compare on the real machine, one attribute apart.
	 * A null keeps the storage's value.
	 */
	public void overrideInterleave(Integer hardskip, Integer softskip, Integer softskew) {
		if (hardskip == null && softskip == null && softskew == null) {
			return;
		}
		interleave = new Interleave(
				hardskip == null ? interleave.hardskip : hardskip,
				softskip == null ? interleave.softskip : softskip,
				softskew == null ? interleave.softskew : softskew,
				segment.sectors);
	}

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
