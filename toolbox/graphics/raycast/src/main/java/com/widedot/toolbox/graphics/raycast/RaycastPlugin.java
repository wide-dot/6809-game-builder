package com.widedot.toolbox.graphics.raycast;

import java.io.File;
import java.nio.file.Paths;

import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.spi.BuildContext;
import com.widedot.m6809.gamebuilder.spi.configuration.Attribute;
import com.widedot.m6809.gamebuilder.spi.globals.Machines;

import lombok.extern.slf4j.Slf4j;

/**
 * Handler for the {@code <raycast>} element : the tables of the engine's
 * raycaster ({@code engine/graphics/raycast}), which casts a ray a screen
 * column in a grid map and writes the column descriptors the wall scalers
 * draw. Two forms :
 * <ul>
 * <li>{@code tables} (default) : the raycaster unit's constants and tables,
 * to assemble before the engine's {@code raycast.unit.asm} — the map (an
 * indexed picture, a pixel a cell : 0 empty, n texture n), the distance and
 * height tables, and per height the scaler the builder placed ;</li>
 * <li>{@code angles} : per angle the rays of the view, a file of its own
 * (12 KB).</li>
 * </ul>
 * The view is shared with {@code <wallscaler>} :
 * {@code <default name="raycast.xxx">}.
 */
@Slf4j
public class RaycastPlugin {

	public static File getFile(ImmutableNode node, BuildContext ctx) throws Exception {
		Settings s;
		try {
			s = Settings.of(node, ctx);
		} catch (Exception e) {
			throw new Exception(ctx.sources.locate(node) + ": <raycast> " + e.getMessage(), e);
		}
		String form = Attribute.getString(node, ctx, "form", "tables");
		String gensource = Attribute.getString(node, ctx, "gensource");
		RayTables t = new RayTables(s.geometry);
		if ("angles".equals(form)) {
			return WallscalerPlugin.write(ctx, gensource, Sources.angles(t));
		}
		if (!"tables".equals(form)) {
			throw new Exception(ctx.sources.locate(node) + ": <raycast form=\"" + form + "\"> : tables or angles");
		}
		Machines.Machine machine = ctx.machines.required("<raycast>");
		GridMap map;
		int textures;
		try {
			textures = TextureEncoder.read(Paths.get(ctx.path, Attribute.getString(node, ctx, "textures")).toString())
					.count();
			map = GridMap.read(Paths.get(ctx.path, Attribute.getString(node, ctx, "map")).toString(), textures);
		} catch (Exception e) {
			throw new Exception(ctx.sources.locate(node) + ": <raycast> " + e.getMessage(), e);
		}
		double radius = Settings.real(node, ctx, "radius", 0.3);
		if (radius < 0.05 || radius > 0.45) {
			throw new Exception(ctx.sources.locate(node) + ": <raycast radius> : " + radius
					+ " cell — the camera's distance to a wall, 0.05 to 0.45");
		}
		boolean pair = "true".equals(Settings.string(node, ctx, "pair", "true"));
		log.info("raycast tables : map {}x{}, {} textures, {} heights ({})", map.width, map.height, textures,
				s.geometry.heights().size(), s.describe());
		return WallscalerPlugin.write(ctx, gensource, Sources.tables(s, t, map, textures,
				(int) Math.rint(radius * 256), pair, machine.pageInclude, machine.pageExpr));
	}
}
