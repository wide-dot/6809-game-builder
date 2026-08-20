package com.widedot.toolbox.graphics.png;

import java.io.File;
import java.nio.file.Files;
import java.nio.file.Paths;

import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.spi.Binary;
import com.widedot.m6809.gamebuilder.spi.BuildContext;
import com.widedot.m6809.gamebuilder.spi.ObjectDataInterface;
import com.widedot.m6809.gamebuilder.spi.configuration.Attribute;
import com.widedot.m6809.util.FileUtil;
import com.widedot.toolbox.graphics.engine.Mscroll;

import lombok.extern.slf4j.Slf4j;

/**
 * Handler for the &lt;mscroll&gt; element : one indexed map PNG becomes the
 * assets of the mscroll engine module. One direntry holds ONE of them,
 * selected by the output attribute :
 *
 *   &lt;mscroll filename="mire.png" gendir="gen/mire" output="map"/&gt;
 *   &lt;mscroll filename="mire.png" gendir="gen/mire" output="tiles" plane="0"/&gt;
 *   &lt;mscroll filename="mire.png" gendir="gen/mire" output="start" plane="0"/&gt;
 *
 * Every invocation also (re)writes &lt;gendir&gt;/&lt;name&gt;.mscroll.equ with the
 * map geometry (MAP_WIDTH, MAP_HEIGHT, ROWSHIFT, TILES), which the game mode
 * includes to feed the _mscroll.set* macros. The generated binary is written
 * next to it for inspection.
 */
@Slf4j
public class MscrollPlugin {

	public static ObjectDataInterface getObject(ImmutableNode node, BuildContext ctx) throws Exception {

		String filename  = Attribute.getString(node, ctx, "filename");
		String output    = Attribute.getString(node, ctx, "output");
		String gendir    = Attribute.getStringOpt(node, ctx, "gendir");
		Integer plane    = Attribute.getInteger(node, ctx, "plane", 0);
		Integer viewh    = Attribute.getInteger(node, ctx, "viewheight", 200);
		String symbol    = Attribute.getStringOpt(node, ctx, "symbol");
		Boolean shift    = Attribute.getBoolean(node, ctx, "shiftcolors", true);

		File png = new File(ctx.path + File.separator + filename);
		String base = FileUtil.removeExtension(png.getName());
		if (symbol == null) symbol = base;

		Mscroll m = new Mscroll(png, shift);

		byte[] data;
		if ("map".equals(output)) {
			data = m.map();
		} else if ("tiles".equals(output)) {
			data = m.tiles(plane);
		} else if ("start".equals(output)) {
			data = m.start(plane, viewh);
		} else {
			throw new Exception("mscroll : output '" + output + "' is not map, tiles or start");
		}

		// every invocation materializes the whole set : the first <mscroll>
		// of the config makes the generated binaries available to the units
		// that INCLUDEBIN them (the start buffers append their wrap jmp)
		if (gendir != null) {
			String dir = ctx.path + File.separator + gendir;
			Files.createDirectories(Paths.get(dir));
			Files.write(Paths.get(dir, base + ".map.bin"), m.map());
			Files.write(Paths.get(dir, base + ".tiles.0.bin"), m.tiles(0));
			Files.write(Paths.get(dir, base + ".tiles.1.bin"), m.tiles(1));
			Files.write(Paths.get(dir, base + ".start.0.bin"), m.start(0, viewh));
			Files.write(Paths.get(dir, base + ".start.1.bin"), m.start(1, viewh));
			Files.write(Paths.get(dir, base + ".mscroll.equ"),
			            m.equ(symbol).getBytes());
		}

		log.info("mscroll {} {} plane {} : {} bytes", png.getName(), output, plane, data.length);
		return new Binary(data);
	}
}
