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

		for (ImmutableNode child : node.getChildren()) {
			if (!"region".equals(child.getNodeName())) {
				throw new Exception(ctx.sources.locate(child) + ": <layout> only contains <region> elements, found <"
						+ child.getNodeName() + ">");
			}

			String name = Attribute.getString(child, ctx, "name");
			int page = Attribute.getInteger(child, ctx, "page");
			int address = Attribute.getInteger(child, ctx, "address");
			Integer size = Attribute.getIntegerOpt(child, ctx, "size");

			try {
				ctx.regions.put(new Regions.Region(name, page, address, size));
			} catch (Exception e) {
				throw new Exception(ctx.sources.locate(child) + ": " + e.getMessage());
			}
			log.debug("region {} : page {} address {} size {}", name, page, address, size);
		}

		log.debug("End of processing layout");
	}
}
