package com.widedot.toolbox.debug;

import java.io.File;
import java.io.FileNotFoundException;
import java.util.HashMap;
import java.util.Map;
import java.util.Scanner;
import java.util.TreeMap;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class Symbols {

	public static Map<String, TreeMap<String, String>> maps = new HashMap<String, TreeMap<String, String>>();
	public static TreeMap<String, String> symbols = new TreeMap<String, String>();
	
	public static void addMap(String fileName) {
		File f = new File(fileName);
		if (!f.exists()) {
			System.err.println("file not found !");
		}

		Pattern regex = Pattern.compile("Symbol:\\s([^\\r\\n\\t\\f\\v @]+)\\s[^=]*\\s=\\s([0-9a-fA-F]{4})");
		Scanner scanner;

		try {
			scanner = new Scanner(f);
			TreeMap<String, String> map = new TreeMap<String, String>();
			
			while (scanner.hasNextLine()) {
				String line = scanner.nextLine();
				Matcher m = regex.matcher(line);
				if (m.matches()) {
					map.put(m.group(1), m.group(2));
				}

			}
			scanner.close();
			
			maps.put(fileName, map);
			buildUnifiedMap();
			
		} catch (FileNotFoundException e) {
			log.error("Error loading symbols !");
			e.printStackTrace();
		}
	}
	
	public static void buildUnifiedMap() {
		// merge all symbols into one Map
		for (String file : maps.keySet()) {
			TreeMap<String, String> currentMap = maps.get(file);
			for (String symbol : currentMap.keySet()) {
				symbols.put(symbol, currentMap.get(symbol));
			}
		}
	}
	
	public static String get(String key) {
		for (String file : maps.keySet()) {
			if (maps.get(file).containsKey(key)) {
				return maps.get(file).get(key);
			}
		}
		return null;
	}
}
