package com.widedot.m6809.gamebuilder;

import java.util.HashMap;
import java.util.Map;

import com.widedot.m6809.gamebuilder.plugin.asm.AsmPlugin;
import com.widedot.m6809.gamebuilder.plugin.bin.BinPlugin;
import com.widedot.m6809.gamebuilder.plugin.cksumfd640.Cksumfd640Plugin;
import com.widedot.m6809.gamebuilder.plugin.data.DataPlugin;
import com.widedot.m6809.gamebuilder.plugin.defaults.DefaultPlugin;
import com.widedot.m6809.gamebuilder.plugin.define.DefinePlugin;
import com.widedot.m6809.gamebuilder.plugin.directory.DirectoryPlugin;
import com.widedot.m6809.gamebuilder.plugin.direntry.DirEntryPlugin;
import com.widedot.m6809.gamebuilder.plugin.fd.FdPlugin;
import com.widedot.m6809.gamebuilder.plugin.floppydisk.FloppyDiskPlugin;
import com.widedot.m6809.gamebuilder.plugin.hfe.HfePlugin;
import com.widedot.m6809.gamebuilder.plugin.includebin.IncludeBinPlugin;
import com.widedot.m6809.gamebuilder.plugin.label.LabelPlugin;
import com.widedot.m6809.gamebuilder.plugin.lwasm.LwasmPlugin;
import com.widedot.m6809.gamebuilder.plugin.sap.SapPlugin;
import com.widedot.m6809.gamebuilder.plugin.sd.SdPlugin;
import com.widedot.m6809.gamebuilder.spi.DefaultPluginInterface;
import com.widedot.m6809.gamebuilder.spi.FilePluginInterface;
import com.widedot.m6809.gamebuilder.spi.ObjectPluginInterface;
import com.widedot.m6809.gamebuilder.spi.media.MediaPluginInterface;

/**
 * Everything the builder can find in a configuration file, mapped from the XML
 * element name to the code that handles it.
 *
 * This replaces a ServiceLoader based plugin mechanism whose declarations lived
 * in 47 factory classes and 16 META-INF/services files. Nothing was ever loaded
 * from outside the build, so all that indirection bought was a class of silent
 * failures: a typo in a service file, or a jar that had not been rebuilt, ended
 * up as "Unknown Plugin" far from its cause. Here a handler is one line, and
 * the compiler checks it.
 *
 * Adding a feature: write the handler with the signature of the matching
 * interface, then register it below.
 */
public final class Handlers {

	/** modifies the configuration in scope, produces nothing */
	private static final Map<String, DefaultPluginInterface> DEFAULTS = new HashMap<>();

	/** produces binary data, possibly with load time link information */
	private static final Map<String, ObjectPluginInterface> OBJECTS = new HashMap<>();

	/** writes into the media being built */
	private static final Map<String, MediaPluginInterface> MEDIA = new HashMap<>();

	/** produces a file for a later stage to consume */
	private static final Map<String, FilePluginInterface> FILES = new HashMap<>();

	static {
		// configuration
		DEFAULTS.put("default", DefaultPlugin::run);
		DEFAULTS.put("define", DefinePlugin::run);
		DEFAULTS.put("floppydisk", FloppyDiskPlugin::run);

		// media structure
		MEDIA.put("directory", DirectoryPlugin::run);
		MEDIA.put("direntry", DirEntryPlugin::run);
		MEDIA.put("data", DataPlugin::run);

		// media outputs
		MEDIA.put("fd", FdPlugin::run);
		MEDIA.put("sd", SdPlugin::run);
		MEDIA.put("sap", SapPlugin::run);
		MEDIA.put("hfe", HfePlugin::run);

		// binary producers
		OBJECTS.put("lwasm", LwasmPlugin::getObject);
		OBJECTS.put("bin", BinPlugin::getObject);
		OBJECTS.put("cksumfd640", Cksumfd640Plugin::getObject);

		// asm source producers
		FILES.put("asm", AsmPlugin::getFile);
		FILES.put("label", LabelPlugin::getFile);
		FILES.put("includebin", IncludeBinPlugin::getFile);

		// asset converters
		OBJECTS.put("vgm2ymm", com.widedot.toolbox.audio.vgm2ymm.Vgm2YmmPlugin::getObject);
		OBJECTS.put("vgm2vgc", com.widedot.toolbox.audio.vgm2vgc.Vgm2VgcPlugin::getObject);
		OBJECTS.put("vgm2sfx", com.widedot.toolbox.audio.vgm2sfx.Vgm2SfxPlugin::getObject);
		OBJECTS.put("pcm", com.widedot.toolbox.audio.pcm.PcmPlugin::getObject);
		OBJECTS.put("png2pal", com.widedot.toolbox.graphics.png2pal.Png2PalPlugin::getObject);
		OBJECTS.put("txt2bas", com.widedot.toolbox.text.txt2bas.Txt2BasPlugin::getObject);
		OBJECTS.put("phoneme", com.widedot.toolbox.text.phoneme.PhonemePlugin::getObject);
	}

	private Handlers() {
	}

	public static DefaultPluginInterface getDefault(String name) {
		return DEFAULTS.get(name);
	}

	public static ObjectPluginInterface getObject(String name) {
		return OBJECTS.get(name);
	}

	public static MediaPluginInterface getMedia(String name) {
		return MEDIA.get(name);
	}

	public static FilePluginInterface getFile(String name) {
		return FILES.get(name);
	}

	/** @return true when the element name is handled at all */
	public static boolean isKnown(String name) {
		return DEFAULTS.containsKey(name) || OBJECTS.containsKey(name)
				|| MEDIA.containsKey(name) || FILES.containsKey(name);
	}
}
