package com.widedot.m6809.gamebuilder.configuration;

import java.util.stream.Stream;

import org.apache.commons.configuration2.HierarchicalConfiguration;
import org.apache.commons.configuration2.tree.ImmutableNode;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class Interleave {
	public String name;
	public int skew;
	public int[] sectorMap;
	
	public Interleave(HierarchicalConfiguration<ImmutableNode> node) throws Exception {
		name = node.getString("[@name]", null);
		if (name == null) {
			throw new Exception("name is missing for interleave");
		}
		
		skew = node.getInteger("[@skew]", 0);
		
		sectorMap = Stream.of(node.getString("", "").split(",")).mapToInt(Integer::parseInt).toArray();
	}
	
	public Interleave(int size) throws Exception {
		name = "none";
		skew = 0;
		sectorMap = new int[size];
		for (int i=0; i<size; i++) {
			sectorMap[i] = i;
		}
	}
}
