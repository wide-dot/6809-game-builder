package com.widedot.toolbox.text.ascii2bas;

import java.io.*;

import java.nio.charset.StandardCharsets;
import java.util.HashMap;

import lombok.extern.slf4j.Slf4j;
@Slf4j
public class FileResourcesUtils {

    public static HashMap<byte[], byte[]> getHashMap(String filename) throws Exception {

        FileResourcesUtils app = new FileResourcesUtils();

        log.debug("{}", filename);
        InputStream is = app.getFileFromResourceAsStream(filename);
		return readInputStream(is);
    }

    // get a file from the resources folder
    // works everywhere, IDEA, unit test and JAR file.
    private InputStream getFileFromResourceAsStream(String fileName) {

        // The class loader that loaded the class
        ClassLoader classLoader = getClass().getClassLoader();
        InputStream inputStream = classLoader.getResourceAsStream(fileName);

        // the stream holding the file content
        if (inputStream == null) {
            throw new IllegalArgumentException("file not found! " + fileName);
        } else {
            return inputStream;
        }

    }

    private static HashMap<byte[], byte[]> readInputStream(InputStream is) {

    	HashMap<byte[], byte[]> data = new HashMap<byte[], byte[]>();
    	
        try (InputStreamReader streamReader = new InputStreamReader(is, StandardCharsets.UTF_8);
             BufferedReader reader = new BufferedReader(streamReader)) {

            String line;
            while ((line = reader.readLine()) != null) {
                String[] kv = line.split("\\s");
                if (kv.length==2) data.put(kv[1].getBytes(), hexStringToByteArray(kv[0]));
            }

        } catch (IOException e) {
            e.printStackTrace();
        }
        
		return data;
    }
    
	public static byte[] hexStringToByteArray(String s) {
	    int len = s.length();
	    byte[] data = new byte[len / 2];
	    for (int i = 0; i < len; i += 2) {
	        data[i / 2] = (byte) ((Character.digit(s.charAt(i), 16) << 4)
	                             + Character.digit(s.charAt(i+1), 16));
	    }
	    return data;
	}
}
