package com.widedot.m6809.gamebuilder.plugin.machine;

import java.io.File;

import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.config.XmlLoader;
import com.widedot.m6809.gamebuilder.spi.BuildContext;
import com.widedot.m6809.gamebuilder.spi.configuration.Attribute;
import com.widedot.m6809.gamebuilder.spi.globals.Machines;

import lombok.extern.slf4j.Slf4j;

/**
 * Picks the target machine out of the machine definitions, the way
 * {@code <floppydisk model="…">} picks a media out of {@code storage.xml} :
 * one external file holding every declination, one name to select it.
 *
 * What it brings into the build is small on purpose — the RAM page count the
 * occupancy report draws, and the expression a generated table writes in
 * front of a page number. Both were hard-coded in the builder before ; both
 * belong to the machine.
 */
@Slf4j
public class MachinePlugin {

	private static final String DEFAULT_DEFINITIONS = "engine/config/machine.xml";

	public static void run(ImmutableNode node, BuildContext ctx) throws Exception {

		String name = Attribute.getString(node, ctx, "name");
		String definitions = Attribute.getString(node, ctx, "definitions", DEFAULT_DEFINITIONS);

		File file = new File(ctx.path + File.separator + definitions);
		if (!file.exists() || file.isDirectory()) {
			throw new Exception(ctx.sources.locate(node) + ": machine definitions '"
					+ definitions + "' does not exist");
		}

		XmlLoader.Result result = XmlLoader.load(file);
		for (ImmutableNode child : result.root.getChildren()) {
			if (!"machine".equals(child.getNodeName())
					|| !name.equals(raw(child, "name"))) {
				continue;
			}
			int pages = 0;
			String expr = null;
			String include = null;
			for (ImmutableNode field : child.getChildren()) {
				if ("ram".equals(field.getNodeName())) {
					pages = Integer.parseInt(raw(field, "pages"));
				} else if ("pagebyte".equals(field.getNodeName())) {
					expr = raw(field, "expr");
					include = raw(field, "include");
				}
			}
			if (pages <= 0 || expr == null || include == null) {
				throw new Exception("machine '" + name + "' of " + definitions
						+ " is incomplete : it needs <ram pages=…/> and"
						+ " <pagebyte expr=… include=…/>");
			}
			ctx.machines.declare(new Machines.Machine(name, pages, expr, include));
			ctx.regions.setRamPages(pages);
			log.debug("machine {} : {} RAM pages, page byte '{}'", name, pages, expr);
			return;
		}
		throw new Exception(ctx.sources.locate(node) + ": machine '" + name
				+ "' is not declared in " + definitions);
	}

	/** read literally : a definitions file has no default cascade of its own */
	private static String raw(ImmutableNode node, String key) {
		Object value = node.getAttributes().get(key);
		return value == null ? null : value.toString();
	}
}
