package com.widedot.toolbox.graphics.backlines;

import java.awt.image.BufferedImage;
import java.io.File;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;

import javax.imageio.ImageIO;

import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.spi.BuildContext;
import com.widedot.m6809.gamebuilder.spi.configuration.Attribute;

import lombok.extern.slf4j.Slf4j;

/**
 * Handler for the {@code <backlines>} element : a background picture
 * compiled line by line into a generated source of the surrounding
 * {@code <lwasm>} unit ({@link BackLines}).
 */
@Slf4j
public class BacklinesPlugin {

	public static File getFile(ImmutableNode node, BuildContext ctx) throws Exception {
		String image = Attribute.getString(node, ctx, "image");
		String label = Attribute.getString(node, ctx, "label");
		String gensource = Attribute.getString(node, ctx, "gensource");
		boolean halfline = Attribute.getBoolean(node, ctx, "halfline", false);
		int linebytes = Attribute.getInteger(node, ctx, "linebytes", 40);
		int planedistance = Attribute.getInteger(node, ctx, "planedistance", 0x2000);
		int beam = Attribute.getInteger(node, ctx, "beam", 60);
		Integer maxsize = Attribute.getIntegerOpt(node, ctx, "maxsize");

		BufferedImage im = ImageIO.read(Paths.get(ctx.path, image).toFile());
		if (im == null) {
			throw new Exception(ctx.sources.locate(node) + ": <backlines> cannot read " + image);
		}
		BackLines.Result r;
		try {
			r = BackLines.compile(im, label, halfline, linebytes, planedistance, beam);
		} catch (Exception e) {
			throw new Exception(ctx.sources.locate(node) + ": " + e.getMessage(), e);
		}
		if (maxsize != null && r.size > maxsize) {
			throw new Exception(ctx.sources.locate(node) + ": <backlines> " + label + " is " + r.size
					+ " bytes, over its maxsize of " + maxsize + " (" + r.lines + " drawn lines : fewer lines, or a"
					+ " simpler picture)");
		}
		Path path = Paths.get(ctx.path, gensource);
		if (path.getParent() != null) {
			Files.createDirectories(path.getParent());
		}
		Files.writeString(path, r.source);
		log.info("backlines {} : {} drawn lines of {} bytes a plane, {} bytes of code, {} cycles for every line",
				label, r.lines, r.bytes, r.size, r.cycles);
		return path.toFile();
	}
}
