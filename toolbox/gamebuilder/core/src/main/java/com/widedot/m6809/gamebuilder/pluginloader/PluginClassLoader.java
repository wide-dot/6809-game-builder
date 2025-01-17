package com.widedot.m6809.gamebuilder.pluginloader;

import java.net.URL;
import java.net.URLClassLoader;
import java.util.Arrays;
import java.util.List;

import lombok.extern.slf4j.Slf4j;

/**
 * Loads a plugin leveraging a {@link URLClassLoader}. However, it restricts the
 * plugin from using the system classloader thereby trimming access to all
 * system classes.
 *
 * Only the classes in SHARED_PACKAGES are visible to the plugin.
 */
@Slf4j
public class PluginClassLoader extends URLClassLoader {

	public static final List<String> SHARED_PACKAGES = Arrays.asList(
			"com.widedot.m6809.gamebuilder.spi",
			"com.widedot.m6809.util",
			"org.apache.commons.configuration2",
			"org.slf4j",
			"javax.script",
			"org.json",
			"com.caoccao.javet");

	private final ClassLoader parentClassLoader;

	public PluginClassLoader(URL[] urls, ClassLoader parentClassLoader) {
		super(urls, null);
		this.parentClassLoader = parentClassLoader;
	}

	@Override
	protected Class<?> loadClass(String name, boolean resolve) throws ClassNotFoundException {

		try {
			// has the class loaded already?
			Class<?> loadedClass = findLoadedClass(name);
			if (loadedClass == null) {
				final boolean isSharedClass = SHARED_PACKAGES.stream().anyMatch(name::startsWith);
				if (isSharedClass) {
					loadedClass = parentClassLoader.loadClass(name);
				} else {
					loadedClass = super.loadClass(name, resolve);
				}
			}

			// marked to resolve
			if (resolve) {
				resolveClass(loadedClass);
			}

			return loadedClass;
		} catch (ClassNotFoundException ex) {
			log.error("NoClassDefFoundError: Plugin dependecies should be added to SHARED_PACKAGES in PluginClassLoader.java");
			return null;
		}
	}
}
