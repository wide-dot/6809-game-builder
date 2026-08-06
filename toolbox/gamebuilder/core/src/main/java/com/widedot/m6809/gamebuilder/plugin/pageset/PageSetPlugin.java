package com.widedot.m6809.gamebuilder.plugin.pageset;

import java.io.File;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.Handlers;
import com.widedot.m6809.gamebuilder.plugin.direntry.DirEntryPlugin;
import com.widedot.m6809.gamebuilder.plugin.lwasm.LwasmPlugin;
import com.widedot.m6809.gamebuilder.spi.BuildContext;
import com.widedot.m6809.gamebuilder.spi.ObjectDataInterface;
import com.widedot.m6809.gamebuilder.spi.configuration.Attribute;
import com.widedot.m6809.gamebuilder.spi.globals.PageSets;
import com.widedot.m6809.gamebuilder.spi.globals.Regions;
import com.widedot.m6809.gamebuilder.spi.media.MediaDataInterface;
import com.widedot.m6809.util.FileUtil;

import lombok.extern.slf4j.Slf4j;

/**
 * A dataset spread over the pages of a multi-page region.
 *
 * A file is one file and a file may not exceed a page, so a tileset or an
 * object library bigger than 16 KB has to become several entries. Writing
 * those by hand means choosing where to cut, re-choosing every time the art
 * changes, and keeping a map of what went where — which is precisely the
 * bookkeeping a builder should do.
 *
 * Here the author declares a budget (the region's page count) and a content.
 * The builder compiles the content part by part, measures each one, packs
 * them first fit in declaration order — the same policy v1's allocator used —
 * and emits one file per page. Every symbol's real page is registered, so
 * a table indexing this dataset resolves each entry's page on its own (see
 * StaticLink.pageOf).
 *
 * Two invariants make it safe. Packing regroups *sources*, never cutting an
 * assembled binary, so no routine is split and no relocation is lost. And the
 * member count is the declared page budget rather than the packing result :
 * file ids are handed out before anything is built, so the number of entries
 * has to follow from the configuration alone.
 */
@Slf4j
public class PageSetPlugin {

	/** the page a member of a set occupies, given the region it lives in */
	public static int pageOf(Regions.Region region, int member) {
		return region.zones.get(member).page;
	}

	public static void run(ImmutableNode node, BuildContext ctx, MediaDataInterface media)
			throws Exception {

		String name = Attribute.getString(node, ctx, "name");
		String regionName = Attribute.getString(node, ctx, "region");
		String gendir = Attribute.getString(node, ctx, "gendir");
		String codec = Attribute.getStringOpt(node, ctx, "codec");
		String linkSection = Attribute.getStringOpt(node, ctx, "linkdata");
		String section = Attribute.getStringOpt(node, ctx, "section");
		String bake = Attribute.getStringOpt(node, ctx, "bake");

		Regions.Region region = ctx.regions.get(regionName);
		if (region == null) {
			throw new Exception(ctx.sources.locate(node) + ": pageset '" + name
					+ "' targets unknown region '" + regionName + "' (layout declares: "
					+ ctx.regions.names() + ")");
		}
		// Each zone is one page offered to the set, with its own room : a
		// region no longer promises N identical pages, it lists what it has.
		int zoneCount = region.zones.size();

		// --- the parts, in declaration order -------------------------------
		//
		// Two kinds. Content that can name its pieces — a tileset — is divisible
		// and gets spread. A <block> is one indivisible unit : declared after
		// the divisible content, it lands in whatever room is left, which is how
		// the tail of a set stops being waste. That is the point of putting a
		// stage's own data here rather than in a region of its own : one budget,
		// one resource map.
		List<String[]> parts = new ArrayList<String[]>();
		List<String[]> blocks = new ArrayList<String[]>();   // {part path, symbol}
		List<ImmutableNode> unitNodes = new ArrayList<ImmutableNode>();
		for (ImmutableNode child : node.getChildren()) {
			if ("unit".equals(child.getNodeName())) {
				// the images' index writes <file>$PAGE, and WHICH member file a
				// unit lands in is only known once packed. The measure assembly
				// uses the first member as a placeholder — its link data is
				// thrown away — and the emission regenerates the source with
				// the real member name.
				String[] unit = unit(child, ctx, gendir,
						PageSets.memberNames(name, 1).get(0));
				blocks.add(unit);
				parts.add(unit);
				unitNodes.add(child);
				continue;
			}
			com.widedot.m6809.gamebuilder.spi.PartsPluginInterface handler =
					Handlers.getParts(child.getNodeName());
			if (handler == null) {
				throw new Exception(ctx.sources.locate(child) + ": <" + child.getNodeName()
						+ "> cannot be spread over pages ; a pageset takes content that can"
						+ " name its parts, such as <gfxcomp>, or a <unit>");
			}
			for (String[] part : handler.getParts(child, ctx)) {
				if (!blocks.isEmpty()) {
					throw new Exception(ctx.sources.locate(child) + ": pageset '" + name
							+ "' declares divisible content after a <unit> ; units fill what"
							+ " the spread content leaves, so they come last");
				}
				parts.add(part);
			}
		}
		if (parts.isEmpty()) {
			throw new Exception("pageset '" + name + "' has no content");
		}

		// --- measure ------------------------------------------------------
		// Divisible parts share one assembly (their sizes are read from the
		// export offsets) ; every unit is assembled ALONE, because unit
		// sources legitimately reuse the same internal names.
		int divisibleCount = parts.size() - blocks.size();
		int[] sizes = new int[parts.size()];
		if (divisibleCount > 0) {
			int[] div = measure(name, parts.subList(0, divisibleCount), ctx, gendir);
			System.arraycopy(div, 0, sizes, 0, divisibleCount);
		}
		for (int u = 0; u < blocks.size(); u++) {
			ObjectDataInterface obj = LwasmPlugin.getObject(
					lwasmOf(blocks.get(u)[0]), ctx);
			sizes[divisibleCount + u] = obj.getBytes().length;
		}

		// --- pack : first fit, declaration order ---------------------------
		List<List<Integer>> pages = new ArrayList<List<Integer>>();
		pages.add(new ArrayList<Integer>());
		int used = 0;
		for (int i = 0; i < parts.size(); i++) {
			int capacity = region.zones.get(Math.min(pages.size() - 1, zoneCount - 1)).size;
			if (sizes[i] > capacity) {
				throw new Exception("pageset '" + name + "' : '" + parts.get(i)[1] + "' is "
						+ sizes[i] + " bytes, more than the " + capacity
						+ " bytes of its zone — an item is never split, it has to be made smaller");
			}
			if (used + sizes[i] > capacity) {
				pages.add(new ArrayList<Integer>());
				used = 0;
			}
			pages.get(pages.size() - 1).add(i);
			used += sizes[i];
		}
		// what the packing really needed : pages="auto" reads it back next pass
		ctx.regions.recordPagesUsed(regionName, pages.size());
		if (pages.size() > zoneCount) {
			throw new Exception("pageset '" + name + "' needs " + pages.size()
					+ " pages but region '" + regionName + "' declares " + zoneCount
					+ " zone(s) — give it another <zone>, or put less in the set");
		}
		if (pages.size() < zoneCount) {
			log.warn("pageset {} fills {} of the {} zones region {} declares — the other {}"
					+ " could be given back", name, pages.size(), zoneCount,
					regionName, zoneCount - pages.size());
		}

		// --- emit one file per page ------------------------------------
		List<PageSets.Member> members = new ArrayList<PageSets.Member>();
		List<String> memberNames = PageSets.memberNames(name, zoneCount);
		for (int p = 0; p < zoneCount; p++) {
			List<Integer> content = p < pages.size() ? pages.get(p) : new ArrayList<Integer>();
			String memberName = memberNames.get(p);
			int page = pageOf(region, p);

			// the placement has to be known before the entry is built : its own
			// content may hold a *.static section, and the tables that index
			// this set ask for each symbol's page as soon as it is exported
			ctx.staticLink.place(memberName, page, region.address, "pageset " + name);
			// the set occupies the region as a whole : another set targeting it
			// replaces every member, so their items may share names even when
			// the packing put a given item on different pages
			ctx.staticLink.declareExclusive(memberName, regionName, name);

			List<Integer> divisible = new ArrayList<Integer>();
			List<Integer> units = new ArrayList<Integer>();
			for (int idx : content) {
				(idx < divisibleCount ? divisible : units).add(idx);
			}

			ImmutableNode.Builder entry = new ImmutableNode.Builder();
			entry.name("file").addAttribute("name", memberName);
			if (bake != null)        entry.addAttribute("bake", bake);
			if (codec != null)       entry.addAttribute("codec", codec);
			if (linkSection != null) entry.addAttribute("linkdata", linkSection);
			if (section != null)     entry.addAttribute("section", section);

			// the divisible parts of this page share one assembly, as before ;
			// each unit is its own — the member concatenates the binaries
			if (!divisible.isEmpty() || units.isEmpty()) {
				String source = gendir + File.separator + memberName + ".asm";
				writeMemberSource(ctx, source, parts, divisible);
				entry.addChild(lwasmOf(source));
			}
			for (int u : units) {
				// regenerate with the REAL member file : the placeholder of
				// the measure pass pointed at member 0
				String[] regenerated = unit(unitNodes.get(u - divisibleCount),
						ctx, gendir, memberName);
				entry.addChild(lwasmOf(regenerated[0]));
			}
			DirEntryPlugin.run(entry.create(), ctx, media);

			members.add(new PageSets.Member(memberName, page, region.address));
			log.info("pageset {} page {} : {} parts", name, page, content.size());
		}
		ctx.pageSets.declare(name, members);

		// A block's page is only known once the packing is done, and the game
		// needs it to mount what it holds — the wave spawner reads its data
		// through a page register. One equate per block says where it landed.
		String gensymbols = Attribute.getStringOpt(node, ctx, "gensymbols");
		if (gensymbols != null) {
			StringBuilder out = new StringBuilder("* Generated by pageset " + name
					+ System.lineSeparator());
			String guard = "PAGES_" + name.toUpperCase().replaceAll("[^A-Z0-9]", "_");
			out.append(" IFNDEF ").append(guard).append(System.lineSeparator());
			out.append(guard).append(" equ 1").append(System.lineSeparator());
			for (String[] block : blocks) {
				int index = parts.indexOf(block);
				int p = 0;
				for (int i = 0; i < pages.size(); i++) {
					if (pages.get(i).contains(index)) {
						p = i;
					}
				}
				out.append(block[1]).append(".page equ ").append(pageOf(region, p))
				   .append(System.lineSeparator());
			}
			out.append(" ENDC").append(System.lineSeparator());
			String path = ctx.path + File.separator + gensymbols;
			Files.createDirectories(Paths.get(FileUtil.getDir(path)));
			Files.write(Paths.get(path), out.toString().getBytes(StandardCharsets.UTF_8));
		}
	}

	/**
	 * One indivisible unit of a pageset : its sources concatenated under a
	 * single exported label, so the set can place it and the game can name it.
	 */
	/**
	 * One indivisible object of the set : an entry symbol and its content.
	 *
	 * A unit is ITS OWN ASSEMBLY. The v1 sources all name their entry
	 * {@code Object} and their tables {@code Routines} — two of them in one
	 * assembly collide, which is why v1 compiled every object separately. The
	 * pageset does the same : each unit's sources are concatenated into one
	 * generated file, assembled alone, and the page's member concatenates the
	 * resulting BINARIES, never the sources. The children therefore keep
	 * their normal envelope — EXPORT, SECTION, entry label — exactly as they
	 * would in a standalone <file>.
	 */
	private static String[] unit(ImmutableNode node, BuildContext ctx, String gendir,
			String memberFile) throws Exception {

		String symbol = Attribute.getString(node, ctx, "symbol");
		String name = Attribute.getString(node, ctx, "name", symbol.replace('.', '_'));
		// two kinds of unit, told apart by the author : sources that open
		// their own section and export their own symbol are included as-is ;
		// bare data (a wave table, a text) gets the whole envelope written
		// for it — section, exported label, ends.
		String section = Attribute.getStringOpt(node, ctx, "section");

		StringBuilder out = new StringBuilder("* Generated by pageset unit " + name
				+ System.lineSeparator());
		if (section != null) {
			// EXPORT stays outside the section, as everywhere else
			out.append(symbol).append(" EXPORT").append(System.lineSeparator())
			   .append(" section ").append(section).append(System.lineSeparator())
			   .append(symbol).append(System.lineSeparator());
		}
		BuildContext localCtx = ctx.child();
		String body = Attribute.getStringOpt(node, ctx, "body");
		if (body != null) {
			out.append("        INCLUDE \"").append(ctx.path).append(File.separator)
			   .append(body).append('"').append(System.lineSeparator());
		}
		for (ImmutableNode child : node.getChildren()) {
			String plugin = child.getNodeName();
			com.widedot.m6809.gamebuilder.spi.DefaultPluginInterface defaultHandler =
					Handlers.getDefault(plugin);
			com.widedot.m6809.gamebuilder.spi.FilePluginInterface fileHandler =
					Handlers.getFile(plugin);
			if (defaultHandler == null && fileHandler == null) {
				throw new Exception(ctx.sources.locate(child) + ": <" + plugin
						+ "> is not valid inside a <unit>");
			}
			// a gfxcomp's index references its images through <file>$PAGE :
			// inside a unit, that file is the pageset MEMBER this unit lands
			// in, which the author cannot know. The pageset writes it.
			if ("gfxcomp".equals(plugin) && child.getAttributes().containsKey("genindex")) {
				ImmutableNode.Builder patched = new ImmutableNode.Builder();
				patched.name(child.getNodeName());
				for (java.util.Map.Entry<String, Object> a : child.getAttributes().entrySet()) {
					if (!"file".equals(a.getKey())) {
						patched.addAttribute(a.getKey(), a.getValue());
					}
				}
				patched.addAttribute("file", memberFile);
				for (ImmutableNode grandChild : child.getChildren()) {
					patched.addChild(grandChild);
				}
				child = patched.create();
			}
			if (defaultHandler != null) {
				defaultHandler.run(child, localCtx);
				ctx.publish(localCtx);
			}
			if (fileHandler != null) {
				out.append("        INCLUDE \"")
				   .append(fileHandler.getFile(child, localCtx).getPath())
				   .append('"').append(System.lineSeparator());
				ctx.publish(localCtx);
			}
		}

		if (section != null) {
			out.append(" endsection").append(System.lineSeparator());
		}
		String source = gendir + File.separator + name + ".unit.asm";
		Files.createDirectories(Paths.get(FileUtil.getDir(ctx.path + File.separator + source)));
		Files.write(Paths.get(ctx.path + File.separator + source),
				out.toString().getBytes(StandardCharsets.UTF_8));
		// relative : AsmPlugin prefixes ctx.path itself
		return new String[] { source, symbol };
	}

	/**
	 * Sizes of the parts, measured in batches.
	 *
	 * Sizes come from the distance between consecutive exported symbols, which
	 * is exact because each part contributes one. Reading offsets touches no
	 * global state — in particular it registers no export, which would collide
	 * with the real per-page entries built right after.
	 *
	 * Batching is not an optimisation but a format limit : LWOBJ16 holds
	 * offsets on 16 bits, so an object over 64 KB wraps and its symbol table
	 * reads as noise. A whole tileset passes that ceiling easily — level 1's
	 * pre-shifted plane assembles to 65533 bytes on its own. A batch that
	 * still manages to exceed it is retried in halves, down to a single part,
	 * which is also how a genuinely oversized part surfaces.
	 */
	private static int[] measure(String name, List<String[]> parts, BuildContext ctx, String gendir)
			throws Exception {

		int[] sizes = new int[parts.size()];
		int from = 0;
		int batch = MEASURE_BATCH;
		while (from < parts.size()) {
			int to = Math.min(from + batch, parts.size());
			try {
				measureBatch(name, parts, from, to, ctx, gendir, sizes);
				from = to;
				batch = MEASURE_BATCH;
			} catch (Exception e) {
				if (to - from <= 1) {
					throw e;
				}
				batch = (to - from) / 2;
				log.debug("pageset {} : measuring batch too large to parse, retrying {} parts",
						name, batch);
			}
		}
		return sizes;
	}

	private static void measureBatch(String name, List<String[]> parts, int from, int to,
			BuildContext ctx, String gendir, int[] sizes) throws Exception {

		List<String[]> batch = parts.subList(from, to);
		String source = gendir + File.separator + name + ".measure." + from + ".asm";
		writeMemberSource(ctx, source, batch, null);

		ObjectDataInterface object = LwasmPlugin.getObject(
				lwasmOf(source), ctx);
		Map<String, int[]> offsets = object.getExportOffsets();
		int total = object.getBytes().length;

		int[] starts = new int[batch.size()];
		for (int i = 0; i < batch.size(); i++) {
			int[] at = offsets.get(batch.get(i)[1]);
			if (at == null) {
				throw new Exception("pageset '" + name + "' : part " + batch.get(i)[0]
						+ " does not export '" + batch.get(i)[1] + "', so its size is unknown");
			}
			starts[i] = at[0];
		}

		for (int i = 0; i < batch.size(); i++) {
			int end = i + 1 < batch.size() ? starts[i + 1] : total;
			sizes[from + i] = end - starts[i];
			if (sizes[from + i] <= 0) {
				throw new Exception("pageset '" + name + "' : parts are not laid out in"
						+ " declaration order, '" + batch.get(i)[1] + "' measures "
						+ sizes[from + i]);
			}
		}
	}

	private static void writeMemberSource(BuildContext ctx, String source, List<String[]> parts,
			List<Integer> content) throws Exception {

		StringBuilder out = new StringBuilder("* Generated by pageset" + System.lineSeparator());
		List<Integer> indexes = new ArrayList<Integer>();
		if (content == null) {
			for (int i = 0; i < parts.size(); i++) {
				indexes.add(i);
			}
		} else {
			indexes.addAll(content);
		}
		for (int i : indexes) {
			out.append(parts.get(i)[1]).append(" EXPORT").append(System.lineSeparator());
		}
		out.append(" SECTION code").append(System.lineSeparator());
		for (int i : indexes) {
			out.append("        INCLUDE \"").append(parts.get(i)[0]).append('"')
			   .append(System.lineSeparator());
		}
		if (indexes.isEmpty()) {
			// A member the packing did not fill still has to be a real file.
			// The loader exempts EMPTY files from eviction by destination —
			// export-only files all share the pseudo destination (0,0) and
			// would evict one another — so an empty member would leave the
			// previous set's member alive at that page, its exports still
			// resolvable while the pages around it have changed. One byte is
			// enough to make it evict.
			out.append("        fcb   0").append(System.lineSeparator());
		}
		out.append(" ENDSECTION").append(System.lineSeparator());

		String path = ctx.path + File.separator + source;
		Files.createDirectories(Paths.get(FileUtil.getDir(path)));
		Files.write(Paths.get(path), out.toString().getBytes(StandardCharsets.UTF_8));
	}

	/** a synthesized {@code <file><lwasm><asm/></lwasm></file>} */
	/** parts per measuring assembly ; see measure() for why this is bounded */
	private static final int MEASURE_BATCH = 32;

	/** an lwasm node assembling one source file on its own */
	private static ImmutableNode lwasmOf(String source) {
		ImmutableNode.Builder asm = new ImmutableNode.Builder();
		asm.name("asm").addAttribute("filename", source);
		ImmutableNode.Builder lwasm = new ImmutableNode.Builder();
		lwasm.name("lwasm").addAttribute("gensource", source + ".cat.asm")
			 .addChild(asm.create());
		return lwasm.create();
	}

	private static ImmutableNode member(String name, String source, String codec,
			String linkSection, String section, String bake) {

		ImmutableNode.Builder asm = new ImmutableNode.Builder();
		asm.name("asm").addAttribute("filename", source);

		ImmutableNode.Builder lwasm = new ImmutableNode.Builder();
		lwasm.name("lwasm").addAttribute("gensource", source).addChild(asm.create());

		ImmutableNode.Builder entry = new ImmutableNode.Builder();
		entry.name("file").addAttribute("name", name).addChild(lwasm.create());
		if (bake != null) {
			// the pageset's bake mode travels to every member : a unit packed
			// here resolves its references exactly as it would in its own file
			entry.addAttribute("bake", bake);
		}
		if (codec != null) {
			entry.addAttribute("codec", codec);
		}
		if (linkSection != null) {
			entry.addAttribute("linkdata", linkSection);
		}
		if (section != null) {
			entry.addAttribute("section", section);
		}
		return entry.create();
	}
}
