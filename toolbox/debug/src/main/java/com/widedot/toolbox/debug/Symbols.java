package com.widedot.toolbox.debug;

import java.io.File;
import java.io.FileNotFoundException;
import java.util.HashMap;
import java.util.Scanner;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class Symbols {

	public HashMap<String, Integer> map = new HashMap<String, Integer>();

	public Symbols(String fileName) {

		File f = new File(fileName);
		if (!f.exists()) {
			System.err.println("file not found !");
		}

		Pattern regex = Pattern.compile("Symbol:\\s(\\S+)\\s[^=]*\\s=\\s([0-9a-fA-F]{4})");
		Scanner scanner;

		try {
			scanner = new Scanner(f);
			while (scanner.hasNextLine()) {
				String line = scanner.nextLine();
				Matcher m = regex.matcher(line);
				if (m.matches()) {
					map.put(m.group(1), Integer.parseInt(m.group(2), 16));
				}

			}
			scanner.close();
		} catch (FileNotFoundException e) {
			log.error("Error loading symbols !");
			e.printStackTrace();
		}
	}
}
