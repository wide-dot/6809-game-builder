package com.widedot.m6809.gamebuilder.plugins;

import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.net.URI;
import java.net.URISyntaxException;
import java.net.URL;
import java.net.URLClassLoader;
import java.nio.file.FileSystem;
import java.nio.file.FileSystems;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Collections;
import java.util.Enumeration;
import java.util.List;
import java.util.jar.JarEntry;
import java.util.jar.JarFile;
import java.util.stream.Collectors;

import com.widedot.m6809.gamebuilder.Settings;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class PluginsLoader {
	
	private static String FILE_EXT = ".class";
	private static int EXT_LENGTH = String.valueOf(FILE_EXT).length();

	public PluginsLoader() throws Exception {
		
        List<File> result = getAllFilesFromResource(Settings.values.get("plugin.dir"));
        for (File file : result) {

            String filePath = file.toString();
            log.debug(filePath);

			try (JarFile jarFile = new JarFile(filePath)) {
				Enumeration<JarEntry> e = jarFile.entries();
	
				URL[] urls = { new URL("jar:file:" + filePath + "!/") };
				URLClassLoader cl = URLClassLoader.newInstance(urls);
	
				while (e.hasMoreElements()) {
					JarEntry je = e.nextElement();
					if (je.isDirectory() || !je.getName().endsWith(FILE_EXT)) {
						continue;
					}
	
					String className = je.getName().substring(0, je.getName().length() - EXT_LENGTH);
					className = className.replace('/', '.');
					cl.loadClass(className);
				}
			} catch (Exception e) {
				throw new Exception("unable to load plugin directory: "+e.getMessage());
			}
        }
	}
	
    private List<File> getAllFilesFromResource(String folder)
            throws URISyntaxException, IOException {

            ClassLoader classLoader = getClass().getClassLoader();

            URL resource = classLoader.getResource(folder);

            // dun walk the root path, we will walk all the classes
            List<File> collect = Files.walk(Paths.get(resource.toURI()))
                    .filter(Files::isRegularFile)
                    .map(x -> x.toFile())
                    .collect(Collectors.toList());

            return collect;
        }
}
