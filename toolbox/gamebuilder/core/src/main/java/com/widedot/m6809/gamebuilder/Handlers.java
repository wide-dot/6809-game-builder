package com.widedot.m6809.gamebuilder;

import java.util.HashMap;
import java.util.Map;

import com.widedot.m6809.gamebuilder.plugin.animation.AnimationPlugin;
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
import com.widedot.m6809.gamebuilder.plugin.layout.LayoutPlugin;
import com.widedot.m6809.gamebuilder.plugin.lwasm.LwasmPlugin;
import com.widedot.m6809.gamebuilder.plugin.sap.SapPlugin;
import com.widedot.m6809.gamebuilder.plugin.sd.SdPlugin;
import com.widedot.m6809.gamebuilder.spi.DefaultPluginInterface;
import com.widedot.m6809.gamebuilder.spi.FilePluginInterface;
import com.widedot.m6809.gamebuilder.spi.ObjectPluginInterface;
import com.widedot.m6809.gamebuilder.spi.media.MediaPluginInterface;
import com.widedot.m6809.gamebuilder.spi.schema.ElementSpec;

import static com.widedot.m6809.gamebuilder.spi.schema.ElementSpec.element;
import static com.widedot.m6809.gamebuilder.spi.schema.ElementSpec.AttrType.*;

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

	/** content that can name its parts, so a pageset can pack them into pages */
	private static final Map<String, com.widedot.m6809.gamebuilder.spi.PartsPluginInterface> PARTS =
			new HashMap<>();

	/** declared shape of every element, the attribute contract */
	private static final Map<String, ElementSpec> SPECS = new HashMap<>();

	private static void spec(ElementSpec s) {
		SPECS.put(s.name, s);
	}

	static {
		// structure
		spec(element("configuration").doc("configuration file root"));
		spec(element("target").doc("a build target, selectable with -t")
			.req("name", STRING, "target name"));
		spec(element("floppydisk").doc("build a floppy disk image")
			.req("model", STRING, "disk model declared in the storage file (fd640, fd320, fd158)")
			.req("storage", STRING, "path of the storage geometry file"));
		spec(element("section").doc("named area of the media")
			.req("name", STRING, "section name, referenced by direntry/data")
			.req("track", INT, "first track")
			.req("face", INT, "face 0 or 1")
			.req("sector", INT, "first sector, 1 based"));
		spec(element("directory").doc("file directory written to the media")
			.req("id", INT, "disk id, matched by the loader at run time")
			.req("section", STRING, "section receiving the directory")
			.req("gensymbols", STRING, "generated file of <name> equ <file id> equates")
			.opt("genbinary", STRING, "debug copy of the directory binary"));
		spec(element("direntry").doc("one loadable file of the directory")
			.req("name", STRING, "unique alias, becomes the file id equate")
			.opt("codec", STRING, "zx0 : compress the whole entry as one stream")
			.opt("loadtimelink", STRING, "emit load time link data into the given section")
			.opt("maxsize", INT, "maximum entry size ; past 16384 the stored size wraps, see the warning")
			.opt("section", STRING, "section receiving the entry"));
		spec(element("pageset").doc("a dataset spread over the pages of a multi-page region : the builder packs it and emits one direntry per page")
			.req("name", STRING, "set name ; members are <name>.0 .. <name>.<pages-1>")
			.req("region", STRING, "multi-page region receiving the set")
			.req("gendir", STRING, "directory receiving the generated member sources")
			.opt("codec", STRING, "zx0 : compress each member as one stream")
			.opt("loadtimelink", STRING, "emit load time link data into the given section")
			.opt("section", STRING, "section receiving the members")
			.opt("gensymbols", STRING, "generated file of <block symbol>.page equates, for code that has to mount what a block holds"));
		spec(element("block").doc("one indivisible unit of a pageset, declared after the spread content so it fills what is left")
			.req("name", STRING, "block name, used for the generated source")
			.opt("symbol", STRING, "exported label placed at the start of the block, defaults to name"));
		spec(element("data").doc("raw data written to a section, outside the directory")
			.req("section", STRING, "section receiving the data")
			.opt("maxsize", INT, "maximum size"));
		spec(element("cksumfd640").doc("applies the fd640 boot sector checksum to its content"));

		// declarative scenes
		spec(element("layout").doc("memory layout of the target : the fixed regions scenes load into")
			.opt("gensymbols", STRING, "generated file of <region>.page / <region>.address equates, for the game code to include"));
		spec(element("region").doc("fixed destination shared by every scene that targets it")
			.req("name", STRING, "region name, referenced by <load region=...>")
			.req("page", INT, "destination page id")
			.req("address", INT, "destination address")
			.opt("size", INT, "byte budget, checked against the loaded entry")
			.opt("bulk", BOOL, "the region takes a list of loads per scene, laid out one after the other ; the list is replaced as a whole")
			.opt("pages", INT, "consecutive pages the region spans from page, 1 if omitted ; more declares a budget for a dataset no single page holds")
			.opt("interface", BOOL, "the direntries loaded here are alternatives : they may share export names, must emit the same export list, and must not be loaded anywhere else"));
		spec(element("scene").doc("generated scene table, one loadable directory entry")
			.req("name", STRING, "unique alias, becomes the file id equate")
			.opt("section", STRING, "section receiving the table")
			.opt("gensource", STRING, "generated table source, defaults to gen/scenes/<name>.asm"));
		spec(element("load").doc("one file loaded by the scene ; no destination means link data only")
			.req("name", STRING, "direntry or scene to load")
			.opt("region", STRING, "destination region of the layout")
			.opt("page", INT, "raw destination page, needs address")
			.opt("address", INT, "raw destination address, needs page"));

		// configuration handlers
		spec(element("default").doc("scoped default for an attribute, key is <element>.<attribute>")
			.req("name", STRING, "target attribute, as <element>.<attribute>")
			.req("value", STRING, "default value"));
		spec(element("define").doc("assembler define passed to lwasm")
			.req("symbol", STRING, "symbol name")
			.opt("value", STRING, "value, defaults to 1"));

		// outputs
		spec(element("fd").doc("write the interleaved image as a .fd file")
			.req("filename", STRING, "output file, relative to dist.dir"));
		spec(element("sd").doc("write the image for SDDRIVE as a .sd file")
			.req("filename", STRING, "output file, relative to dist.dir"));
		spec(element("sap").doc("write the image as .sap file(s), one per used drive")
			.req("filename", STRING, "output file, relative to dist.dir")
			.opt("format", INT, "SAP format, 1 (default) or 2"));
		spec(element("hfe").doc("write the image as a .hfe file, needs hxcfe in the PATH")
			.req("filename", STRING, "output file, relative to dist.dir"));

		// binary producers
		spec(element("lwasm").doc("assemble source units into one object")
			.opt("format", STRING, "obj (linkable) or raw")
			.opt("gensource", STRING, "generated concatenated source, also names the build artifacts")
			.opt("processor", STRING, "assembler executable name"));
		spec(element("bin").doc("raw binary file inserted as is")
			.req("filename", STRING, "input file"));
		spec(element("asm").doc("assembly source unit : a file, or inline text").text()
			.opt("filename", STRING, "source file ; omit when using inline text"));
		spec(element("label").doc("exported label with no content, used as an interface")
			.req("name", STRING, "exported symbol"));
		spec(element("includebin").doc("binary included through a generated INCLUDEBIN")
			.req("filename", STRING, "binary file"));
		spec(element("animation").doc("frame table walked by AnimateSprite")
			.req("name", STRING, "exported symbol, the address an object puts in anim")
			.opt("duration", INT, "frames each image is held, 1 by default")
			.opt("end", STRING, "reset (default), goback, goto, nextroutine, resetandsubroutine, nextsubroutine")
			.opt("frames", INT, "frames to step back, with end=goback")
			.opt("animation", STRING, "animation to continue with, with end=goto"));
		spec(element("frame").doc("one frame of an animation")
			.req("image", STRING, "image name ; the frame points at its imageset"));
		spec(element("gfxcomp").doc("compile PNGs into 6809 drawing code, as one source unit")
			.req("gendir", STRING, "directory receiving the compiled images")
			.req("gensource", STRING, "generated source unit of INCLUDE lines")
			.opt("genindex", STRING, "generated imageset index ; omit for images with no index")
			.opt("file", STRING, "direntry name the images end up in ; the index reads their page from <file>$PAGE, required with genindex")
			.opt("linearbits", INT, "video memory linear bits")
			.opt("planarbits", INT, "video memory planar bits")
			.opt("linebytes", INT, "video memory bytes per line")
			.opt("nbplanes", INT, "video memory planes"));
		spec(element("image").doc("one PNG of a gfxcomp unit")
			.req("name", STRING, "image name, prefix of the generated symbols")
			.req("filename", STRING, "input .png, 8 bit indexed, colour 0 transparent")
			.opt("index", INT, "index in the imageset, emitted as idx_<name>")
			.opt("grid", STRING, "tile size <width>x<height> : the png is a tileset, sliced into tiles named <name>_<id> in reading order, each compiled with the declared encoders")
			.opt("range", STRING, "grid only : <first>-<last> tile ids this unit takes of the sheet, for a tileset too big for one page ; ids stay those of the sheet"));
		spec(element("encoder").doc("one compiled rendering of an image")
			.opt("name", STRING, "draw, bdraw, rle or zx0")
			.opt("mirror", STRING, "none, x, y or xy")
			.opt("shift", INT, "pre shift in pixels")
			.opt("position", STRING, "center, top-left or 3qtr-center"));

		// asset converters
		spec(element("vgm2ymm").doc("convert a VGM file to the YM2413 ymm stream")
			.opt("filename", STRING, "input .vgm file or directory")
			.opt("genbinary", STRING, "generated .ymm file")
			.opt("codec", STRING, "zx0 : compress the stream")
			.opt("dac2drum", STRING, "map DAC samples to drums"));
		spec(element("vgm2vgc").doc("convert a VGM file to the SN76489 vgc stream")
			.opt("filename", STRING, "input .vgm file or directory")
			.opt("genbinary", STRING, "generated .vgc file"));
		spec(element("vgm2sfx").doc("convert a VGM file to sound effects source")
			.opt("filename", STRING, "input .vgm file")
			.opt("gensource", STRING, "generated source file"));
		spec(element("pcm").doc("convert PCM samples")
			.opt("filename", STRING, "input file or directory")
			.opt("genbinary", STRING, "generated binary")
			.opt("bit8to6", BOOL, "convert 8 bit samples to the 6 bit DAC"));
		spec(element("png2pal").doc("extract a palette from a PNG")
			.opt("filename", STRING, "input .png")
			.opt("gensource", STRING, "generated source file")
			.opt("symbol", STRING, "generated symbol name")
			.opt("colors", INT, "number of colors")
			.opt("offset", INT, "first color index")
			.opt("mode", STRING, "bin, and only as direntry content ; inside <lwasm> the table is always the exported form")
			.opt("profile", STRING, "color profile"));
		spec(element("txt2bas").doc("tokenize a BASIC text file")
			.req("filename", STRING, "input text file")
			.req("tokenset", STRING, "BASIC token set"));
		spec(element("phoneme").doc("convert text to MEA8000 phonemes")
			.opt("filename", STRING, "input text file")
			.opt("genbinary", STRING, "generated binary")
			.opt("lang", STRING, "language, defaults to fr"));
	}

	static {
		// configuration
		DEFAULTS.put("default", DefaultPlugin::run);
		DEFAULTS.put("define", DefinePlugin::run);
		DEFAULTS.put("floppydisk", FloppyDiskPlugin::run);
		DEFAULTS.put("layout", LayoutPlugin::run);

		// media structure
		MEDIA.put("directory", DirectoryPlugin::run);
		MEDIA.put("pageset", com.widedot.m6809.gamebuilder.plugin.pageset.PageSetPlugin::run);
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
		FILES.put("gfxcomp", com.widedot.toolbox.graphics.gfxcomp.GfxcompPlugin::getFile);
		PARTS.put("gfxcomp", com.widedot.toolbox.graphics.gfxcomp.GfxcompPlugin::getParts);
		FILES.put("tilemap", com.widedot.m6809.gamebuilder.plugin.tilemap.TilemapPlugin::getFile);
		FILES.put("animation", AnimationPlugin::getFile);
		// also an object : inside <lwasm> a linkable table, as direntry content
		// a loadable 32 byte file
		FILES.put("png2pal", com.widedot.toolbox.graphics.png2pal.Png2PalPlugin::getFile);

		// asset converters
		OBJECTS.put("vgm2ymm", com.widedot.toolbox.audio.vgm2ymm.Vgm2YmmPlugin::getObject);
		OBJECTS.put("vgm2vgc", com.widedot.toolbox.audio.vgm2vgc.Vgm2VgcPlugin::getObject);
		OBJECTS.put("vgm2sfx", com.widedot.toolbox.audio.vgm2sfx.Vgm2SfxPlugin::getObject);
		OBJECTS.put("pcm", com.widedot.toolbox.audio.pcm.PcmPlugin::getObject);
		OBJECTS.put("png2pal", com.widedot.toolbox.graphics.png2pal.Png2PalPlugin::getObject);
		spec(element("tilemap").doc("generate the page/address table of a tile index map, baked in a .static section")
			.req("map", STRING, "tile index .bin (leanscroll output), big endian, column major")
			.req("label", STRING, "label of the generated table")
			.req("tiles", STRING, "tile symbol stem : entries reference adr_<tiles>_<id>_<variant>")
			.req("variant", STRING, "compiled tile variant, ND0 for unshifted, ND1 for pre-shifted")
			.req("gensource", STRING, "generated source file of the table")
			.opt("section", STRING, "section of the table, map.static if omitted ; must end with .static")
			.opt("bitdepth", INT, "bits per tile index in the map, 16 if omitted"));
		spec(element("png2bin").doc("convert an indexed PNG to video memory data, one plane per declaration")
			.req("filename", STRING, "input .png")
			.opt("gendir", STRING, "where the generated binaries go, source tree if omitted")
			.opt("videomode", STRING, "t0, t1, t1s, t2, bm16, c2, c4, c16 — the pixel layout")
			.opt("buffer", STRING, "none, vscroll, vscrolltile, hscroll — engine buffer built on top")
			.opt("guardcolor", INT, "hscroll only : the colour the wrapped bytes are refilled with")
			.opt("plane", INT, "which memory plane this declaration yields")
			.opt("part", INT, "which part, when maxsize split the plane")
			.opt("maxsize", INT, "split the plane beyond this size")
			.opt("shiftcolors", BOOL, "index 0 is transparency and 1..16 are colours 0..15")
			.opt("linearbits", INT, "instead of videomode : bits of a pixel held by one plane")
			.opt("planarbits", INT, "instead of videomode : bits written before changing plane")
			.opt("linebytes", INT, "instead of videomode : bytes per line, 0 to fit the image")
			.opt("planes", INT, "instead of videomode : number of memory planes")
			.opt("pixeldepth", INT, "instead of videomode : bits per pixel"));
		OBJECTS.put("png2bin", com.widedot.toolbox.graphics.png.Png2BinPlugin::getObject);
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

	public static com.widedot.m6809.gamebuilder.spi.PartsPluginInterface getParts(String name) {
		return PARTS.get(name);
	}

	public static FilePluginInterface getFile(String name) {
		return FILES.get(name);
	}

	public static ElementSpec spec(String name) {
		return SPECS.get(name);
	}

	public static java.util.Collection<ElementSpec> specs() {
		return SPECS.values();
	}

	/** @return true when the element name is handled at all */
	public static boolean isKnown(String name) {
		return DEFAULTS.containsKey(name) || OBJECTS.containsKey(name)
				|| MEDIA.containsKey(name) || FILES.containsKey(name);
	}
}
