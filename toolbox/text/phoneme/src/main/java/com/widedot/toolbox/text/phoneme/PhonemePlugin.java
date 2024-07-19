package com.widedot.toolbox.text.phoneme;

import java.io.File;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.net.URISyntaxException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import org.json.JSONObject;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class PhonemePlugin {

	public static String FILE_EXT = ".bin";
	public static HashSet<String> LANG = new HashSet<String>(Arrays.asList("fr"));
	
    private static Map<String, String> exceptions;
    private static List<Element> conversion;

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
        String lastResult = "notnull";
        String wordResult = "";
        for (String word : text.split("([\\s|(0-9)|•|—|–|\\-|,|?|!|^|\\r|’|°|“|”|\\.|«|»|…|\\\\|\\/|!|?|\\\"|\\[|\\]|\\(|\\)|\\]|<|>|=|+|%|$|&|#|;|*|:|}|{|`])")) {
            lastResult = wordResult;
            wordResult = "";
            if (exceptions.containsKey(word)) {
                wordResult = exceptions.get(word);
            } else {
            	while (!word.equals("")) {
	                for (Element entry : conversion) {
	                	Matcher m = entry.p.matcher(word) ;  
	                    if (m.find()) {
	                        word = word.substring(m.end()-m.start());
	                        wordResult += entry.value;
	                        break;
	                    }
	                }
            	}
            }
            if (!(lastResult.equals("") && wordResult.equals(""))) {
            	result.add(wordResult);
            }
        }

        System.out.println(result.toString());
        
        byte[] bytes = new byte[10];
		return bytes;
	}

    private static List<Element> parseCSV(String fileName) throws IOException {
        List<Element> result = new ArrayList<Element>();
        
        InputStream is = PhonemePlugin.class.getClassLoader().getResourceAsStream(fileName);
        
        try (BufferedReader br = new BufferedReader(new InputStreamReader(is, StandardCharsets.UTF_8))) {
            String line;
            while ((line = br.readLine()) != null) {
                String[] parts = line.split("#");
               	result.add(new Element(parts[0], (parts.length==1?"":parts[1]), Pattern.compile(parts[0])));
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