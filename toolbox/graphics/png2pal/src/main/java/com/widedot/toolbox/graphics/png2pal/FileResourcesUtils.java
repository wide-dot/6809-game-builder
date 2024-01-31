package com.widedot.toolbox.graphics.png2pal;

import java.io.*;

import java.nio.charset.StandardCharsets;
import java.util.HashMap;

import com.widedot.m6809.util.color.LAB;

import lombok.extern.slf4j.Slf4j;
@Slf4j
public class FileResourcesUtils {

    public static int[] get(String filename) throws Exception {

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

    private static int[] readInputStream(InputStream is) {

        int[] data = new int[16];
    	
        try (InputStreamReader streamReader = new InputStreamReader(is, StandardCharsets.UTF_8);
             BufferedReader reader = new BufferedReader(streamReader)) {

            String line;
            int i=0;
            while ((line = reader.readLine()) != null) {
            	data[i++] = Integer.parseInt(line);
            }
            
        } catch (IOException e) {
            e.printStackTrace();
        }
        
		return data;
    }
}
