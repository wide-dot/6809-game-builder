package com.widedot.m6809.gamebuilder.spi.configuration;

import java.util.HashMap;

public class Defaults {

	public HashMap<String, String> values = new HashMap<String, String>();

	public Defaults() {
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
