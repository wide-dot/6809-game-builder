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

	/** content that can name its parts, so the arena packer can cut between them */
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
			.req("name", STRING, "section name, referenced by file/data")
			.req("track", INT, "first track")
			.req("face", INT, "face 0 or 1")
			.req("sector", INT, "first sector, 1 based"));
		spec(element("directory").doc("file directory written to the media")
			.req("id", INT, "disk id, matched by the loader at run time")
			.req("section", STRING, "section receiving the directory")
			.req("gensymbols", STRING, "generated file of <name> equ <file id> equates")
			.opt("genbinary", STRING, "debug copy of the directory binary"));
		spec(element("file").doc("one loadable file of the directory")
			.req("name", STRING, "unique alias, becomes the file id equate")
			.opt("codec", STRING, "zx0 (default) compresses the whole entry as one stream ; none stores it raw with no compression block — for content whose raw path is the point")
			.opt("linkdata", STRING, "emit load time link data into the given section")
			.opt("maxsize", INT, "maximum entry size ; past 16384 the stored size wraps, see the warning")
			.opt("section", STRING, "section receiving the entry")
			.opt("bake", STRING, "reference resolution: auto (default), none, all")
			// the attributed place : the file declares its destination once,
			// and every <load> that names it reduces to the name — read
			// literally by the placement scan, one form of the three at most
			.opt("arena", STRING, "attributed place : arena to range this file into ; loads of it become bare names")
			.opt("region", STRING, "attributed place : destination region of the layout ; loads of it become bare names")
			.opt("page", INT, "attributed place : raw destination page, needs address")
			.opt("address", INT, "attributed place : raw destination address, needs page")
			.opt("gendir", STRING, "collection form (every child names its parts) : directory receiving the generated member sources"));
		spec(element("unit").doc("one indivisible object — an entry symbol and its content, code and images alike. In a <file> the builder generates its envelope")
			.opt("name", STRING, "name for the generated source, defaults from symbol")
			.req("symbol", STRING, "exported label placed at the start of the unit")
			.opt("section", STRING, "for bare data : the builder writes the whole envelope — section, exported symbol, ends. Omit it when the sources open their own section and export their own symbol")
			.opt("body", STRING, "shorthand for a single <asm> child")
			.opt("gendir", STRING, "file form : directory receiving the generated source (default gen/units)"));
		spec(element("data").doc("raw data written to a section, outside the directory")
			.req("section", STRING, "section receiving the data")
			.opt("maxsize", INT, "maximum size")
			.opt("ram-page", INT, "page this data stays resident in (the loader) : reserves its MEASURED size on the RAM map")
			.opt("ram-address", INT, "address the data is loaded at, required with ram-page")
			.opt("ram-pool", STRING, "reserves a further block right after the code (the TLSF pool sits there) ; a size, fill-to:<address> to take everything up to a boundary (the loader's half-page), or the name of a <define>"));
		spec(element("cksumfd640").doc("applies the fd640 boot sector checksum to its content"));

		// declarative scenes
		spec(element("machine").doc("the target machine, picked out of the machine definitions the way <floppydisk model=…> picks a media out of storage.xml")
			.req("name", STRING, "machine name declared in the definitions file (to8, mo6)")
			.req("definitions", STRING, "path of the machine definitions file"));
		spec(element("layout").doc("memory layout of the target : the fixed regions scenes load into")
			.opt("gensymbols", STRING, "generated file of <region>.page / <region>.address equates, for the game code to include")
			.opt("pages", INT, "physical RAM pages of the machine, for the occupancy report — 32 (512K) if omitted, 8 for a 128K MO6"));
		spec(element("region").doc("fixed destination shared by every scene that targets it")
			.req("name", STRING, "region name, referenced by <load region=...>")
			.opt("page", INT, "destination page, compact form of a region holding one <zone>")
			.opt("address", INT, "destination address, compact form")
			.opt("size", INT, "byte budget of the compact form ; a region declaring <zone> children says its room there")
			.opt("pages", INT, "consecutive pages of the compact form, 1 if omitted — the same as declaring that many <zone>"));
		spec(element("arena").doc("a named list of zones the builder ranges files over, largest first. Its content is reached through a table — never through a baked address — which is what lets the builder move it")
			.req("name", STRING, "arena name, referenced by <load arena=...>"));
		spec(element("zone").doc("a continuous range inside one page — the only thing that speaks of physical memory. Declare several to describe a discontinuous space ; a zone never spans pages")
			.req("page", INT, "page holding this range")
			.req("address", INT, "where the range starts")
			.req("size", INT, "how many bytes it offers"));
		spec(element("reserved").doc("a range the game occupies without loading into it — object pool, globals, stack, direct page ; nothing may be placed on top")
			.req("name", STRING, "range name, emitted as <name>.address / <name>.size equates")
			.req("page", INT, "page holding the range")
			.req("address", INT, "first byte")
			.req("size", INT, "length in bytes"));
		spec(element("scene").doc("generated scene table, one loadable directory entry")
			.req("name", STRING, "unique alias, becomes the file id equate")
			.opt("section", STRING, "section receiving the table")
			.opt("gensource", STRING, "generated table source, defaults to gen/scenes/<name>.asm"));
		spec(element("load").doc("one file loaded by the scene, by name only : where it lands is the file's attributed place ; a file that declares none is export-only (link data, nothing written)")
			.req("name", STRING, "file or scene to load"));

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
			.opt("file", STRING, "file name the images end up in ; the index reads their page from <file>$PAGE, required with genindex")
			.opt("imageset", STRING, "name the measured geometry is handed over under, for an <imageset> element to index a set whose code is spread over pages")
			.opt("section", STRING, "SECTION wrapping the generated includes, code if omitted ; none for a host that already opened one")
			.opt("linearbits", INT, "video memory linear bits")
			.opt("planarbits", INT, "video memory planar bits")
			.opt("linebytes", INT, "video memory bytes per line")
			.opt("nbplanes", INT, "video memory planes")
			.opt("planedistance", INT, "bytes between the two halves of the video window, 8192 if omitted ; only planes=offset needs it"));
		spec(element("image").doc("one PNG of a gfxcomp unit")
			.req("name", STRING, "image name, prefix of the generated symbols")
			.req("filename", STRING, "input .png, 8 bit indexed, colour 0 transparent")
			.opt("index", INT, "index in the imageset, emitted as idx_<name>")
			.opt("grid", STRING, "tile size <width>x<height> : the png is a tileset, sliced into tiles named <name>_<id> in reading order, each compiled with the declared encoders"));
		spec(element("leanscroll").doc("the level-map chain, run by the build : from one level picture, the two scroll planes (the odd one pre-shifted by a pixel) as tileset strips plus column-major 16 bit maps, windowed and renumbered under gendir — even.png/even.bin/odd.png/odd.bin, consumed by a <gfxcomp grid> and a <tilemap>. Cached on the picture and the parameters")
			.req("image", STRING, "the level picture, one tile row per map row")
			.req("gendir", STRING, "directory receiving the planes and the windowed outputs")
			.opt("tile", STRING, "tile size <width>x<height>, 12x12 if omitted")
			.opt("columns", INT, "window width in columns — the whole level if omitted")
			.opt("first", INT, "window's first column, 0 if omitted")
			.opt("gensymbols", STRING, "generated equates of the window's geometry (map.COLS, map.ROWS)")
			.opt("lean", BOOL, "false : no lean pass, the picture is tiled AS IT IS (everything else is unchanged — tiling, dedup, pre-shifted plane, window, maps, equates). The pass drops the pixels a scroll sweep would repaint anyway, which only pays when the engine SCROLLS the playfield ; an overlay renderer clears the field and repaints every tile every frame. Default true, and then scrollstep/nbsteps apply")
			.opt("scrollstep", STRING, "the module's scroll vector, default 0,0,1,0,0,0,0,0 — the engine's 1 px horizontal dual-plane scroll. Feeds the lean pass only")
			.opt("nbsteps", STRING, "the module's sub-step counts, default 0,0,4,0,0,0,0,0. Feeds the lean pass only")
			.opt("refresh", STRING, "cells forced to stay DRAWN (bound to the set's first tile) though the lean would empty them : a checkpoint restart repaints from the map, so a band the scroll cannot rebuild from its start-of-stage blocks needs them. Space or comma list of <col>:<row> or <col>:<rowFirst>-<rowLast>"));
		spec(element("images").doc("a SERIES of images, declared as one line : the files of a directory in their NN order-prefix order, all compiled alike. Imageset indexes continue across rows and literal <image> alike ; symbol names are <base>_<n> with one counter per base, so a mirror row of the same directory continues the numbering")
			.req("dir", STRING, "series directory ; files are ordered by their NN numeric prefix (the order IS the name)")
			.opt("match", STRING, "glob filter on the file names, *.png if omitted")
			.opt("encoder", STRING, "draw, bdraw, rle or zx0 — bdraw if omitted")
			.opt("mirror", STRING, "none (default), x, y or xy — applied to every file of the row")
			.opt("shifts", STRING, "comma list of pre-shifts, one compiled variant each ; defaults through <default name=\"images.shifts\"> — the target's one-line d7/t2 decision — then to 0. A row may pin its own (the player and the boss pre-shift even on floppy)")
			.opt("names", STRING, "symbol base, <base>_<n> ; derived from the series directory if omitted (its parent when the directory is a plain images/)")
			.opt("index", STRING, "none : the images are reached by name only — no imageset index is assigned, no idx byte grows the descriptors. Default auto : indexes continue when the gfxcomp carries genindex or imageset")
			.opt("position", STRING, "center, top-left or 3qtr-center, forwarded to every encoder of the row")
			.opt("planes", STRING, "pointer or offset, forwarded to every encoder of the row"));
		spec(element("encoder").doc("one compiled rendering of an image")
			.opt("name", STRING, "draw, bdraw, rle or zx0")
			.opt("mirror", STRING, "none, x, y or xy")
			.opt("shift", INT, "pre shift in pixels")
			.opt("position", STRING, "center, top-left or 3qtr-center")
			.opt("planes", STRING, "how the code reaches the second video plane : pointer (default, from glb_screen_location_1, U consumed) or offset (at planedistance from U, U given back — for a caller drawing a row of sprites). draw encoder only"));

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
			.opt("mode", STRING, "bin, and only as file content ; inside <lwasm> the table is always the exported form")
			.opt("section", STRING, "name of the generated SECTION, default code")
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
		DEFAULTS.put("machine", com.widedot.m6809.gamebuilder.plugin.machine.MachinePlugin::run);
		DEFAULTS.put("leanscroll",
				com.widedot.toolbox.graphics.tilemap.leanscroll.LeanscrollPlugin::run);

		// media structure
		MEDIA.put("directory", DirectoryPlugin::run);
		MEDIA.put("file", DirEntryPlugin::run);
		MEDIA.put("data", DataPlugin::run);

		// media outputs
		MEDIA.put("fd", FdPlugin::run);
		MEDIA.put("sd", SdPlugin::run);
		MEDIA.put("sap", SapPlugin::run);
		MEDIA.put("hfe", HfePlugin::run);

		// binary producers
		OBJECTS.put("lwasm", LwasmPlugin::getObject);
		OBJECTS.put("unit", com.widedot.m6809.gamebuilder.plugin.unit.UnitPlugin::unitObject);
		OBJECTS.put("bin", BinPlugin::getObject);
		OBJECTS.put("cksumfd640", Cksumfd640Plugin::getObject);

		// asm source producers
		FILES.put("asm", AsmPlugin::getFile);
		FILES.put("label", LabelPlugin::getFile);
		FILES.put("includebin", IncludeBinPlugin::getFile);
		FILES.put("gfxcomp", com.widedot.toolbox.graphics.gfxcomp.GfxcompPlugin::getFile);
		PARTS.put("gfxcomp", com.widedot.toolbox.graphics.gfxcomp.GfxcompPlugin::getParts);
		// a unit is ONE element : the packer may cut between it and its
		// neighbours, never inside it — the word that groups plugins whose
		// output must stay continuous (5d)
		PARTS.put("unit", com.widedot.m6809.gamebuilder.plugin.unit.UnitPlugin::getParts);
		FILES.put("tilemap", com.widedot.m6809.gamebuilder.plugin.tilemap.TilemapPlugin::getFile);
		FILES.put("tilepatch", com.widedot.m6809.gamebuilder.plugin.tilemap.TilepatchPlugin::getFile);
		FILES.put("tilereset", com.widedot.m6809.gamebuilder.plugin.tilemap.TileresetPlugin::getFile);
		FILES.put("imageset", com.widedot.toolbox.graphics.gfxcomp.ImagesetPlugin::getFile);
		FILES.put("animation", AnimationPlugin::getFile);
		// also an object : inside <lwasm> a linkable table, as file content
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
			.req("tiles", STRING, "the file hosting the tiles : entries reference adr_<host>_<id>_<variant>")
			.req("variant", STRING, "compiled tile variant, ND0 for unshifted, ND1 for pre-shifted")
			.req("gensource", STRING, "generated source file of the table")
			.opt("section", STRING, "section of the table, map if omitted")
			.opt("bitdepth", INT, "bits per tile index in the map, 16 if omitted"));
		spec(element("tilepatch").doc("generate the animation blocks tilemap.patch writes into a scroll map, and the descriptor its sequencer reads, baked in a .static section")
			.req("map", STRING, "tile index .bin of the frame strip (leanscroll output), frames laid side by side, column major")
			.req("label", STRING, "label of the generated descriptor")
			.opt("mapodd", STRING, "the odd plane's index .bin — omit when the camera is parked and only one plane is ever read")
			.req("tiles", STRING, "the file hosting the even plane's tiles : entries reference adr_<host>_<id>_<variant>")
			.opt("tilesodd", STRING, "the file hosting the odd plane's tiles — goes with mapodd")
			.req("variant", STRING, "compiled tile variant, ND0 for unshifted, ND1 for pre-shifted")
			.opt("variantodd", STRING, "the odd plane's variant, same as variant if omitted")
			.opt("gensymbols", STRING, "generated equates of the geometry, for the object driving the clock")
			.req("cols", INT, "width of one frame, in map cells")
			.req("rows", INT, "height of one frame, in map cells")
			.req("frames", INT, "number of frames in the strip")
			.req("gensource", STRING, "generated source file")
			.opt("col", INT, "destination column in the map, 0 if omitted")
			.opt("row", INT, "destination row in the map, 0 if omitted")
			.opt("hold", INT, "video frames each animation frame is held, 1 if omitted")
			.opt("first", INT, "index of the first frame in the strip, 0 if omitted — lets several animations share one cut and one tileset")
			.opt("section", STRING, "section of the blocks, map if omitted")
			.opt("bitdepth", INT, "bits per tile index in the map, 16 if omitted"));
		spec(element("tilereset").doc("from a list of map rectangles, generate what puts those cells back the way the level shipped them — the map in RAM is the only copy, and a checkpoint return does not reload it")
			.req("map", STRING, "the LEVEL's tile index .bin — the source of truth for the original cells")
			.req("maprows", INT, "rows per column in that map, so a rectangle can be located")
			.req("label", STRING, "label of the generated table")
			.req("tiles", STRING, "the file hosting the LEVEL's tiles : the restore names those, so nothing is compiled twice")
			.req("variant", STRING, "compiled tile variant of those tiles")
			.req("gensource", STRING, "generated source file")
			.opt("section", STRING, "section of the table, map if omitted")
			.opt("bitdepth", INT, "bits per tile index in the map, 16 if omitted"));
		spec(element("rect").doc("one patchable rectangle of the map, inside <tilereset>")
			.req("col", INT, "left column")
			.req("row", INT, "top row")
			.req("cols", INT, "width in cells")
			.req("rows", INT, "height in cells"));
		spec(element("imageset").doc("index of an imageset whose drawing code is spread over pages, baked in a .static section")
			.req("name", STRING, "imageset name, as declared by the <gfxcomp imageset> that compiled the images")
			.req("gensource", STRING, "generated source file of the index")
			.opt("section", STRING, "section of the index, code if omitted"));
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
		spec(element("mscroll").doc("build one mscroll asset (tile-major tileset, map or start buffer) from an indexed map PNG")
			.req("filename", STRING, "input .png : the whole map, indexed, a whole number of 8x16 tiles")
			.req("output", STRING, "map, tiles or start — which asset this direntry holds")
			.opt("gendir", STRING, "where the generated binaries and the .mscroll.equ go")
			.opt("plane", INT, "memory plane for tiles and start (0 or 1)")
			.opt("viewheight", INT, "start only : lines of the initial view (default 200)")
			.opt("symbol", STRING, "prefix of the generated equates (default : the file name)")
			.opt("shiftcolors", BOOL, "index 0 is transparency and 1..16 are colours 0..15"));
		OBJECTS.put("mscroll", com.widedot.toolbox.graphics.png.MscrollPlugin::getObject);
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
