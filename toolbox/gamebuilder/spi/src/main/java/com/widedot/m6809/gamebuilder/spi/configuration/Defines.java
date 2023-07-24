package com.widedot.m6809.gamebuilder.spi.configuration;

import java.util.HashMap;

public class Defines {

	public HashMap<String, String> values;
	public HashMap<String, String> newValues;
	
	public Defines() {
		values = new HashMap<String, String>();
		newValues = new HashMap<String, String>();
	}

	@SuppressWarnings("unchecked")
	public Defines(HashMap<String, String> map) {
		values = (HashMap<String, String>) map.clone();
		newValues = new HashMap<String, String>();
	}
	
	public void publish(Defines local) {
		newValues.putAll(local.newValues);    // propagate to parent
		local.values.putAll(local.newValues); // propagate to local
		local.newValues.clear();              // clear values
	}

}
