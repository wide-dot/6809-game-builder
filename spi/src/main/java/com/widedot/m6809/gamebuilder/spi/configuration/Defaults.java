package com.widedot.m6809.gamebuilder.spi.configuration;

import java.util.HashMap;
import java.util.List;

import org.apache.commons.configuration2.HierarchicalConfiguration;
import org.apache.commons.configuration2.tree.ImmutableNode;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class Defaults {

	public HashMap<String, String> values;

	public Defaults() {
		values = new HashMap<String, String>();
	}

	public void add(HierarchicalConfiguration<ImmutableNode> node) throws Exception {
		log.debug("Reading default values ...");
		List<HierarchicalConfiguration<ImmutableNode>> defaults = node.configurationsAt("default");
		for (HierarchicalConfiguration<ImmutableNode> defaultTags : defaults) {
    		String name = defaultTags.getString("[@name]", null);
    		String value = defaultTags.getString("[@value]", null);
    		values.put(name, value);
    		log.debug("default name: {} value: {}", name, value);
		}
	}

	// default Integer value when plugin does not exists
	public Integer getInteger(String name, Integer defaultVal) {
		return (values.containsKey(name) ? Integer.parseInt(values.get(name)) : defaultVal);
	}

	// default String value when plugin does not exists
	public String getString(String name, String defaultVal) {
		return (values.containsKey(name) ? values.get(name) : defaultVal);
	}
}
