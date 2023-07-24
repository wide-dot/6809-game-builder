package com.widedot.m6809.gamebuilder.spi.configuration;

import java.util.HashMap;

public class Defaults {

	public HashMap<String, String> values;

	public Defaults() {
		values = new HashMap<String, String>();
	}

	@SuppressWarnings("unchecked")
	public Defaults(HashMap<String, String> map) {
		values = (HashMap<String, String>) map.clone();
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
