package com.widedot.m6809.util;

import java.io.*;
import java.nio.charset.StandardCharsets;
import java.util.HashMap;

public class FileResourcesUtils {

    public static HashMap<String, String> getHashMap(String filename) throws Exception {

        FileResourcesUtils app = new FileResourcesUtils();

        System.out.println("getResourceAsStream : " + filename);
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

    private static HashMap<String, String> readInputStream(InputStream is) {

    	HashMap<String, String> data = new HashMap<String, String>();
    	
        try (InputStreamReader streamReader = new InputStreamReader(is, StandardCharsets.UTF_8);
             BufferedReader reader = new BufferedReader(streamReader)) {

            String line;
            while ((line = reader.readLine()) != null) {
                String[] kv = line.split("=");
                if (kv.length==2) data.put(kv[0], kv[1]);
            }

        } catch (IOException e) {
            e.printStackTrace();
        }
        
		return data;
    }

}
