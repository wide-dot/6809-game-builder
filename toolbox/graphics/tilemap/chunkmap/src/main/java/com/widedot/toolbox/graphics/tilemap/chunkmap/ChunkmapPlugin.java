package com.widedot.toolbox.graphics.tilemap.chunkmap;

import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.List;

import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.spi.BuildContext;
import com.widedot.m6809.gamebuilder.spi.configuration.Attribute;

import lombok.extern.slf4j.Slf4j;

/**
 * Handler for the {@code <chunkmap>} element : a chunked tilemap (the Mega
 * Drive Sonic games' levels : layouts of chunks of 8x8 blocks) converted to
 * the TilemapBuffer formats by the build, under {@code gendir=} — tiles.png
 * for a {@code <gfxcomp grid>}, tiles.bin for the {@code <tilemap>} that
 * indexes it, the chunk banks, the acts' layouts and the collision tables.
 * The conversion is {@link ChunkMap}'s.
 */
@Slf4j
public class ChunkmapPlugin {

	public static void run(ImmutableNode node, BuildContext ctx) throws Exception {
		String chunks = Attribute.getString(node, ctx, "chunks");
		String mappings = Attribute.getString(node, ctx, "mappings");
		String blocks = Attribute.getString(node, ctx, "blocks");
		String primary = Attribute.getString(node, ctx, "primary");
		String secondary = Attribute.getString(node, ctx, "secondary");
		String layouts = Attribute.getString(node, ctx, "layouts");
		String gendir = Attribute.getString(node, ctx, "gendir");
		boolean halfline = Attribute.getBoolean(node, ctx, "halfline", false);
		boolean opaque = Attribute.getBoolean(node, ctx, "opaque", false);
		String animated = Attribute.getStringOpt(node, ctx, "animated");

		List<Path> lay = new ArrayList<Path>();
		for (String l : layouts.split(",")) {
			lay.add(Paths.get(ctx.path, l.trim()));
		}
		ChunkMap.Result r;
		try {
			r = ChunkMap.run(Paths.get(ctx.path, chunks), Paths.get(ctx.path, mappings),
					Paths.get(ctx.path, blocks), Paths.get(ctx.path, primary),
					Paths.get(ctx.path, secondary), lay, halfline, opaque, animated,
					Paths.get(ctx.path, gendir));
		} catch (Exception e) {
			throw new Exception(ctx.sources.locate(node) + ": " + e.getMessage(), e);
		}
		log.info("chunkmap {} : {} tiles, {} chunks, {} layouts under {}", chunks, r.tileCount,
				r.chunks.size(), r.layouts.size(), gendir);
	}
}
