package com.widedot.m6809.gamebuilder.plugin.collection;

import java.io.File;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.plugin.direntry.DirEntryPlugin;
import com.widedot.m6809.gamebuilder.plugin.lwasm.LwasmPlugin;
import com.widedot.m6809.gamebuilder.plugin.unit.UnitPlugin;
import com.widedot.m6809.gamebuilder.spi.BuildContext;
import com.widedot.m6809.gamebuilder.spi.ObjectDataInterface;
import com.widedot.m6809.gamebuilder.spi.configuration.Attribute;
import com.widedot.m6809.gamebuilder.spi.globals.Cuts;
import com.widedot.m6809.gamebuilder.spi.globals.PageSets;
import com.widedot.m6809.gamebuilder.spi.media.MediaDataInterface;
import com.widedot.m6809.util.FileUtil;

import lombok.extern.slf4j.Slf4j;

/**
 * A COLLECTION is an ordinary {@code <file>} whose top-level children can all
 * name their parts. It needs no word of its own : the frontier is the PLUGIN —
 * lwasm yields one element, gfxcomp exposes N, {@code <unit>} exactly one —
 * and the placement's rule is the author's "whole if it fits, cut between
 * elements if it does not" (5c). This class holds what the two sides of that
 * rule share :
 *
 * <ul>
 * <li>{@link #measure} — element sizes, asked by the packer before it sorts.
 *     Divisible parts share batched assemblies (sizes read from export
 *     offsets) ; every unit is assembled ALONE, because unit sources
 *     legitimately reuse the same internal names ;</li>
 * <li>{@link #emit} — the member entries, one per chunk the packer decided,
 *     the single-chunk case keeping the file's own name. A member holding a
 *     unit concatenates BINARIES : one assembly per divisible run, one per
 *     unit, in element order — never their sources.</li>
 * </ul>
 *
 * The cut itself is the ARENA PACKER's decision, recorded in {@link Cuts} :
 * deciding here too would let the two disagree, which the reserved==emitted
 * assertion refuses.
 */
@Slf4j
public class CollectionPlugin {

	/**
	 * A measure assembly cannot exceed 64 KB (LWOBJ16 offsets are 16 bits),
	 * so parts are measured in batches.
	 */
	private static final int MEASURE_BATCH = 192;

	/**
	 * Measure each part's size. Consecutive divisible parts are measured from
	 * one batched assembly's export offsets ; each unit part is assembled
	 * alone and measured by its binary length.
	 */
	public static int[] measure(String name, List<String[]> parts,
			Map<Integer, ImmutableNode> units, BuildContext ctx, String gendir)
			throws Exception {

		int[] sizes = new int[parts.size()];
		int i = 0;
		while (i < parts.size()) {
			if (units.containsKey(i)) {
				ObjectDataInterface obj = LwasmPlugin.getObject(
						UnitPlugin.lwasmOfUnit(parts.get(i)[0]), ctx);
				sizes[i] = obj.getBytes().length;
				i++;
				continue;
			}
			int to = i;
			while (to < parts.size() && !units.containsKey(to)) {
				to++;
			}
			measureRun(name, parts, i, to, ctx, gendir, sizes);
			i = to;
		}
		return sizes;
	}

	/** measure one run of divisible parts, in batches bounded by the format */
	private static void measureRun(String name, List<String[]> parts, int from, int to,
			BuildContext ctx, String gendir, int[] sizes) throws Exception {
		int at = from;
		int batch = MEASURE_BATCH;
		while (at < to) {
			int end = Math.min(at + batch, to);
			try {
				measureBatch(name, parts, at, end, ctx, gendir, sizes);
				at = end;
				batch = MEASURE_BATCH;
			} catch (Exception e) {
				if (end - at <= 1) {
					throw e;
				}
				batch = (end - at) / 2;
				log.debug("collection {} : measuring batch too large to parse, retrying {} parts",
						name, batch);
			}
		}
	}

	private static void measureBatch(String name, List<String[]> parts, int from, int to,
			BuildContext ctx, String gendir, int[] sizes) throws Exception {

		List<String[]> batch = parts.subList(from, to);
		String source = gendir + File.separator + name + ".measure." + from + ".asm";
		writeMemberSource(ctx, source, batch, null, java.util.Collections.emptyMap());

		ObjectDataInterface object = LwasmPlugin.getObject(lwasmOf(source), ctx);
		Map<String, int[]> offsets = object.getExportOffsets();
		int total = object.getBytes().length;

		int[] starts = new int[batch.size()];
		for (int i = 0; i < batch.size(); i++) {
			int[] at = offsets.get(batch.get(i)[1]);
			if (at == null) {
				throw new Exception("collection '" + name + "' : part " + batch.get(i)[0]
						+ " does not export '" + batch.get(i)[1] + "', so its size is unknown");
			}
			starts[i] = at[0];
		}

		for (int i = 0; i < batch.size(); i++) {
			int end = i + 1 < batch.size() ? starts[i + 1] : total;
			sizes[from + i] = end - starts[i];
			if (sizes[from + i] <= 0) {
				throw new Exception("collection '" + name + "' : parts are not laid out in"
						+ " declaration order, '" + batch.get(i)[1] + "' measures "
						+ sizes[from + i]);
			}
		}
	}

	/**
	 * Emission : one entry per chunk of the packer's cut. A single chunk is
	 * the file placed WHOLE — one entry under the file's own name ; several
	 * chunks are the members a scene expands to, {@code <file>.0}, {@code .1}…
	 * Within a member the elements keep declaration order : each run of
	 * divisible parts becomes one generated assembly, each unit is its own —
	 * the entry concatenates the binaries.
	 */
	public static void emit(ImmutableNode node, BuildContext ctx, MediaDataInterface media)
			throws Exception {

		String name = Attribute.getString(node, ctx, "name");
		Cuts.Cut cut = ctx.cuts.get(name);
		if (cut == null) {
			throw new Exception(ctx.sources.locate(node) + ": collection '" + name
					+ "' was never packed — is it loaded by a scene into an arena ?");
		}

		// the entry attributes travel to every member, the codec written out
		// as the EFFECTIVE decision ("none" included : an omitted attribute
		// would be re-defaulted to zx0 by the entry)
		String codec = DirEntryPlugin.effectiveCodec(Attribute.getStringOpt(node, ctx, "codec"));
		String linkSection = Attribute.getStringOpt(node, ctx, "linkdata");
		String section = Attribute.getStringOpt(node, ctx, "section");
		String bake = Attribute.getStringOpt(node, ctx, "bake");

		List<PageSets.Member> members = ctx.pageSets.get(name);
		for (int c = 0; c < cut.chunks.size(); c++) {
			String memberName;
			int page;
			int address;
			if (cut.chunks.size() == 1) {
				memberName = name;
				int[] at = ctx.regions.filePlacement(name);
				if (at == null) {
					throw new Exception("collection '" + name
							+ "' was cut into one chunk but has no placement");
				}
				page = at[0];
				address = at[1];
			} else {
				PageSets.Member member = members.get(c);
				memberName = member.name;
				page = member.page;
				address = member.address;
			}

			// the placement has to be known before the entry is built : the
			// tables that index this collection ask each symbol's page as soon
			// as it is exported
			ctx.staticLink.place(memberName, page, address, "collection " + name);

			ImmutableNode.Builder entry = new ImmutableNode.Builder();
			entry.name("file").addAttribute("name", memberName);
			if (bake != null)        entry.addAttribute("bake", bake);
			entry.addAttribute("codec", codec != null ? codec : "none");
			if (linkSection != null) entry.addAttribute("linkdata", linkSection);
			if (section != null)     entry.addAttribute("section", section);

			// element order is binary order : divisible runs share an
			// assembly, units are regenerated for the member they landed in
			// (a nested genindex writes <member>$PAGE) and assembled alone
			List<Integer> chunk = cut.chunks.get(c);
			int run = 0;
			int i = 0;
			while (i < chunk.size()) {
				int part = chunk.get(i);
				ImmutableNode unitNode = cut.units.get(part);
				if (unitNode != null) {
					String unitGendir = Attribute.getString(unitNode, ctx, "gendir",
							"gen/units");
					String[] regenerated = UnitPlugin.unit(unitNode, ctx, unitGendir,
							memberName);
					entry.addChild(UnitPlugin.lwasmOfUnit(regenerated[0]));
					i++;
					continue;
				}
				List<Integer> runParts = new ArrayList<Integer>();
				while (i < chunk.size() && cut.units.get(chunk.get(i)) == null) {
					runParts.add(chunk.get(i));
					i++;
				}
				// the first run keeps the member's own source name — the shape
				// every all-divisible collection has always had
				String source = cut.gendir + File.separator + memberName
						+ (run == 0 ? "" : ".d" + run) + ".asm";
				writeMemberSource(ctx, source, cut.parts, runParts, cut.units);
				entry.addChild(lwasmOf(source));
				run++;
			}
			DirEntryPlugin.run(entry.create(), ctx, media);

			log.info("collection {} : member {} ({} parts) at page {} ${}", name, memberName,
					cut.chunks.get(c).size(), page,
					Integer.toHexString(address).toUpperCase());
		}
	}

	/** one member's source : exports first, then the parts, in chunk order */
	public static void writeMemberSource(BuildContext ctx, String source, List<String[]> parts,
			List<Integer> content, Map<Integer, ImmutableNode> units) throws Exception {

		StringBuilder out = new StringBuilder("* Generated collection member"
				+ System.lineSeparator());
		List<Integer> indexes = new ArrayList<Integer>();
		if (content == null) {
			for (int i = 0; i < parts.size(); i++) {
				indexes.add(i);
			}
		} else {
			indexes.addAll(content);
		}
		for (int i : indexes) {
			if (units.containsKey(i)) {
				throw new Exception("collection member source '" + source + "' would include"
						+ " a unit — units are assembled alone, never share a source");
			}
			out.append(parts.get(i)[1]).append(" EXPORT").append(System.lineSeparator());
		}
		out.append(" SECTION code").append(System.lineSeparator());
		for (int i : indexes) {
			out.append("        INCLUDE \"").append(parts.get(i)[0]).append('"')
			   .append(System.lineSeparator());
		}
		out.append(" ENDSECTION").append(System.lineSeparator());

		String path = ctx.path + File.separator + source;
		Files.createDirectories(Paths.get(FileUtil.getDir(path)));
		Files.write(Paths.get(path), out.toString().getBytes(StandardCharsets.UTF_8));
	}

	private static ImmutableNode lwasmOf(String source) {
		ImmutableNode.Builder asm = new ImmutableNode.Builder();
		asm.name("asm").addAttribute("filename", source);
		ImmutableNode.Builder lwasm = new ImmutableNode.Builder();
		lwasm.name("lwasm").addAttribute("gensource", source + ".cat.asm")
			 .addChild(asm.create());
		return lwasm.create();
	}
}
