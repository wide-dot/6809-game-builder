package com.widedot.m6809.gamebuilder.plugin;

import java.net.URL;
import java.net.URLClassLoader;
import java.util.Enumeration;
import java.util.jar.JarEntry;
import java.util.jar.JarFile;

import com.widedot.m6809.gamebuilder.Settings;

public class ClassLoader {
	
	private static int extLength = String.valueOf(".class").length();

	public ClassLoader() throws Exception {
		
		String pathToJar = Settings.values.get("plugin.dir");
		
		JarFile jarFile = new JarFile(pathToJar);
		Enumeration<JarEntry> e = jarFile.entries();

		URL[] urls = { new URL("jar:file:" + pathToJar + "!/") };
		URLClassLoader cl = URLClassLoader.newInstance(urls);

		while (e.hasMoreElements()) {
			JarEntry je = e.nextElement();
			if (je.isDirectory() || !je.getName().endsWith(".class")) {
				continue;
			}
			// -6 because of .class
			String className = je.getName().substring(0, je.getName().length() - extLength);
			className = className.replace('/', '.');
			cl.loadClass(className);
		}
	}
}
