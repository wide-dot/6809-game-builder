package com.widedot.m6809.gamebuilder.plugin.layout;

import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.spi.BuildContext;
import com.widedot.m6809.gamebuilder.spi.configuration.Attribute;
import com.widedot.m6809.gamebuilder.spi.globals.Regions;

import lombok.extern.slf4j.Slf4j;

/**
 * Declares the memory layout of a target : named regions at fixed
 * destinations, that scene loads reference instead of raw page/address pairs.
 */
@Slf4j
public class LayoutPlugin {

	public static void run(ImmutableNode node, BuildContext ctx) throws Exception {

		log.debug("Processing layout ...");

		String gensymbols = Attribute.getStringOpt(node, ctx, "gensymbols");

		for (ImmutableNode child : node.getChildren()) {
			if (!"region".equals(child.getNodeName())) {
				throw new Exception(ctx.sources.locate(child) + ": <layout> only contains <region> elements, found <"
						+ child.getNodeName() + ">");
			}

			String name = Attribute.getString(child, ctx, "name");
			int page = Attribute.getInteger(child, ctx, "page");
			int address = Attribute.getInteger(child, ctx, "address");
			Integer size = Attribute.getIntegerOpt(child, ctx, "size");
			boolean bulk = Attribute.getBoolean(child, ctx, "bulk", false);

			try {
				ctx.regions.put(new Regions.Region(name, page, address, size, bulk));
			} catch (Exception e) {
				throw new Exception(ctx.sources.locate(child) + ": " + e.getMessage());
			}
			log.debug("region {} : page {} address {} size {}{}", name, page, address, size,
					bulk ? " bulk" : "");
		}

		// export the layout as equates : the game code includes this file
		// instead of duplicating pages and addresses by hand ("as defined in
		// scene file" comments are exactly the smell this removes)
		if (gensymbols != null) {
			String path = ctx.path + java.io.File.separator + gensymbols;
			java.nio.file.Files.createDirectories(
					java.nio.file.Paths.get(com.widedot.m6809.util.FileUtil.getDir(path)));
			StringBuilder out = new StringBuilder();
			for (Regions.Region region : ctx.regions.all()) {
				out.append(region.name).append(".page equ ").append(region.page)
				   .append(System.lineSeparator());
				out.append(region.name).append(".address equ $")
				   .append(String.format("%04X", region.address)).append(System.lineSeparator());
			}
			java.nio.file.Files.write(java.nio.file.Paths.get(path),
					out.toString().getBytes(java.nio.charset.StandardCharsets.UTF_8));
			log.debug("layout symbols written to {}", gensymbols);
		}

		log.debug("End of processing layout");
	}
}
