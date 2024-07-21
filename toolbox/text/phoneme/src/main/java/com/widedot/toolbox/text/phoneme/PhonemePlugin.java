package com.widedot.toolbox.text.phoneme;

import java.io.File;
import java.io.FileOutputStream;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.net.URISyntaxException;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.io.BufferedReader;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import org.json.JSONObject;

import com.widedot.m6809.util.FileUtil;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class PhonemePlugin {

	public static String filename;
	public static String genbinary;
	public static String lang;
	
	public static List<String> INPUT_EXT;
	public static String OUTPUT_EXT = ".asm";
	public static HashSet<String> LANG = new HashSet<String>(Arrays.asList("fr"));
	
    private static Map<String, String> exceptions;
    private static List<Element> conversion;
    
    static {
    	INPUT_EXT = new ArrayList<String>();
    	INPUT_EXT.add(".txt");
    	
    }
    
	public static byte[] run() throws Exception {

		log.debug("Convert {} to {}", INPUT_EXT, OUTPUT_EXT);
		
		// check input file
		File file = new File(filename);
		if (!file.exists()) {
			String m = "filename: "+filename+" does not exists !";
			log.error(m);
			throw new Exception(m);
		}

		ByteArrayOutputStream outputStream = new ByteArrayOutputStream( );

		if (!file.isDirectory()) {

			// Single file processing
			outputStream.write(convertFile(file));

		} else {

			// Directory processing
			for (String fileExt: INPUT_EXT) {
				processDirectory(outputStream, file, fileExt);
			}
		}
		log.debug("Conversion ended sucessfully.");

		return outputStream.toByteArray();
	}


	private static void processDirectory(ByteArrayOutputStream outputStream, File file, String fileExt) throws Exception {

		log.debug("Process each {} file of the directory: {}", fileExt, file.getAbsolutePath());

		File[] files = file.listFiles((d, name) -> name.endsWith(fileExt));
		for (File curFile : files) {
			outputStream.write(convertFile(curFile));
		}
	}


	private static byte[] convertFile(File file) throws Exception {

		String outFileName;
		if (genbinary == null || genbinary.equals(""))
		{
			// output is not specified, produce file in same directory as input file
			outFileName = FileUtil.removeExtension(file.getAbsolutePath()) + OUTPUT_EXT;
		} else {
			if (Files.isDirectory(Paths.get(genbinary))) {
				// output directory is specified
				outFileName = genbinary + File.separator + FileUtil.removeExtension(file.getName()) + OUTPUT_EXT;
			} else {
				// output file is specified
				outFileName = genbinary;
			}
		}

		Files.createDirectories(Paths.get(FileUtil.getDir(outFileName)));
		
		File outFile = new File(outFileName);
		
		// prevent ouput file to overwrite input file
		if (outFile.getAbsolutePath().equals(file.getAbsolutePath())) {
			String m = "input and output filename cannot be the same !";
			log.error(m);
			throw new Exception(m);
		}
		
		// skip processing if input file is older than output file
		long inputLastModified = file.lastModified();
		long outputLastModified = outFile.lastModified();
		
		if (inputLastModified > outputLastModified) {
		
			log.debug("Generating: {}", outFileName);
			
			ByteArrayOutputStream outputStream = write(file);	
			
			Files.createDirectories(Paths.get(FileUtil.getDir(outFileName)));
			OutputStream fileStream = new FileOutputStream(outFileName);
			outputStream.writeTo(fileStream);
			outputStream.close();
			
			return outputStream.toByteArray();
			
		} else {
			log.debug("Build cache for {}", outFileName);
			return Files.readAllBytes(Paths.get(outFileName));
		}
	}
	
    public static ByteArrayOutputStream write(File file) throws Exception { 
		
		ArrayList<String> ipa = TXT2IPA(file);
		byte[] mea = IPA2MEA(ipa);

		ByteArrayOutputStream outputStream = new ByteArrayOutputStream();
		outputStream.write(mea);
		outputStream.close();
		
		return outputStream;	
    }	
    
    public static byte[] IPA2MEA(ArrayList<String> ipa) throws Exception {
    	
    	ByteBuffer buffer = ByteBuffer.allocate(16000000);
    	boolean first = true;
    	for (String word: ipa) {
    		if (!first) {
    			buffer.put(("\tfcb " + Mea8000.SYMBOL_PREFIX + Mea8000.WORD_DELIMITER + "\n").getBytes());
    		}
	    	while (!word.equals("")) {
	    		boolean found = false;
	            for (Element entry : Mea8000.symbols) {
	            	Matcher m = entry.p.matcher(word) ;  
	                if (m.find()) {
	                    word = word.substring(m.end()-m.start());
	                    buffer.put(("\tfcb " + Mea8000.SYMBOL_PREFIX + entry.value + "\n").getBytes());
	                    found = true;
	                    break;
	                }
	            }
	            if (!found) {
	            	word = word.substring(1); // skip unkown char
	            }
	    	}
	    	first = false;
    	}
    	
    	buffer.put(("\tfcb " + Mea8000.SYMBOL_PREFIX + Mea8000.END_DELIMITER + "\n").getBytes());

    	// flush buffer
    	int size = buffer.position();
    	byte[] result = new byte[size];
    	for (int i = 0; i < size; i++) {
    		result[i] = buffer.get(i);
    	}

		return result;
    	
    }

	public static ArrayList<String> TXT2IPA(File file) throws Exception {

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
        String wordResult = "";
        
        for (String word : text.split("((?=\\s|\\.|\\,|\\;|\\?|\\!)|(?<=\\s|\\.|\\,|\\;|\\?|\\!))")) {
            wordResult = "";
            
            word = word.toLowerCase();
            if (exceptions.containsKey(word)) {
            	
            	// Use dictionnary
                wordResult = exceptions.get(word);
                
            } else {
            	
            	// Use regexp
            	while (!word.equals("")) {
            		boolean found = false;
	                for (Element entry : conversion) {
	                	Matcher m = entry.p.matcher(word) ;  
	                    if (m.find()) {
	                        word = word.substring(m.end()-m.start());
	                        wordResult += entry.value;
	                        found = true;
	                        break;
	                    }
	                }
	                if (!found) {
	                	word = word.substring(1); // skip unkown char
	                }
            	}
            }
            if (!wordResult.equals("")) {
            	result.add(wordResult);
            }
        }
        
        return result;
	}

    private static List<Element> parseCSV(String fileName) throws IOException {
        List<Element> result = new ArrayList<Element>();
        
        InputStream is = PhonemePlugin.class.getClassLoader().getResourceAsStream(fileName);
        
        try (BufferedReader br = new BufferedReader(new InputStreamReader(is, StandardCharsets.UTF_8))) {
            String line;
            while ((line = br.readLine()) != null) {
                String[] parts = line.split("#");
               	result.add(new Element(parts[0], (parts.length==1?"":parts[1])));
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