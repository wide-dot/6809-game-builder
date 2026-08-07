package com.widedot.m6809.gamebuilder.spi.configuration;

import java.util.HashMap;
import java.util.Map;

import lombok.extern.slf4j.Slf4j;

/**
 * Build settings, loaded from settings.properties.
 *
 * Immutable for the duration of a build and carried by the BuildContext rather
 * than held statically, so that two builds in the same JVM cannot see each
 * other's configuration.
 */
@Slf4j
public class Settings {

	private static final String[] MANDATORY_KEYS = {
		"build.dir", "build.dir.tag", "plugin.dir", "plugin.package",
		"generate.unnamedFiles.dir", "dist.dir", "file.zx0.delta"
	};

	private final Map<String, String> values;

	public Settings(Map<String, String> values) {
		this.values = new HashMap<String, String>(values);
	}

	public String get(String key) {
		return values.get(key);
	}

	public int getInt(String key) throws Exception {
		String v = values.get(key);
		try {
			return Integer.parseInt(v);
		} catch (NumberFormatException e) {
			throw new Exception("setting " + key + " is not a number: " + v);
		}
	}

	public boolean isValid() {
		boolean state = true;
		for (String key : MANDATORY_KEYS) {
			String v = values.get(key);
			if (v == null || v.isEmpty()) {
				log.error("Missing key:{} in settings.properties", key);
				state = false;
			}
		}
		return state;
	}
}
