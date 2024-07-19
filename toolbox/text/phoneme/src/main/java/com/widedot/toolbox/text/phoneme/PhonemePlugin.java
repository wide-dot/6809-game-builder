package com.widedot.toolbox.text.phoneme;

import java.io.File;
import java.io.FileInputStream;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.HashSet;
import java.net.URISyntaxException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.io.BufferedReader;
import java.io.ByteArrayOutputStream;
import java.io.DataInputStream;
import java.io.DataOutputStream;
import java.io.FileReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.util.Map;
import org.json.JSONObject;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class PhonemePlugin {

	public static String FILE_EXT = ".bin";
	public static HashSet<String> LANG = new HashSet<String>(Arrays.asList("fr"));
	
    private static Map<String, String> exceptions;
    private static Map<String, String> conversion;

	public static byte[] convert(File file, String lang) throws Exception {

		// control input parameters
		if (!file.exists() || file.isDirectory()) {
			log.error("Input file: {} does not exists !", file.toString());
			return null;
		}
		if (!LANG.contains(lang)) {
			log.error("lang: {} is not supported, available languages are: ", lang, LANG);
			return null;
		}

        exceptions = parseJSON(lang + ".json");
        conversion = parseCSV(lang + ".csv");
		
        ArrayList<String> result = new ArrayList<>();
        String text = new String (Files.readAllBytes(file.toPath())).toLowerCase();
        for (String word : text.split(" ")) {
            String wordResult = "";
            if (exceptions.containsKey(word)) {
                wordResult = exceptions.get(word);
            } else {
                for (Map.Entry<String, String> entry : conversion.entrySet()) {
                    if (word.matches(".*" + entry.getKey() + ".*")) {
                        word = word.replaceFirst(entry.getKey(), "");
                        wordResult += entry.getValue();
                    }
                }
            }
            result.add(wordResult);
            result.add(".");
        }
        if (!result.isEmpty() ) {
        	result.remove(result.size()-1);
        }

        System.out.println("/"+result.toString()+"/");
        
        byte[] bytes = new byte[10];
		return bytes;
	}

    private static Map<String, String> parseCSV(String fileName) throws IOException {
        Map<String, String> result = new HashMap<>();
        
        InputStream is = PhonemePlugin.class.getClassLoader().getResourceAsStream(fileName);
        
        try (BufferedReader br = new BufferedReader(new InputStreamReader(is, StandardCharsets.UTF_8))) {
            String line;
            while ((line = br.readLine()) != null) {
                String[] parts = line.split("#");
                if (result.containsKey(parts[0])) {
                	log.info("key: "+parts[0]+" already exists, value will be updated.");
                }
               	result.put(parts[0], (parts.length==1?"":parts[1]));
            }
        }
        return result;
    }

    private static Map<String, String> parseJSON(String fileName) throws IOException, URISyntaxException {
        Map<String, String> result = new HashMap<>();
        
        InputStream stream = PhonemePlugin.class.getClassLoader().getResourceAsStream(fileName);
        JSONObject json = new JSONObject(new String(stream.readAllBytes()));
        for (String key : json.keySet()) {
            result.put(key, json.getString(key));
        }
        return result;
    }

}