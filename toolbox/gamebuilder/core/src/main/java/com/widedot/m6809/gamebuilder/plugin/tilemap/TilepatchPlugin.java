package com.widedot.m6809.gamebuilder.plugin.tilemap;

import java.io.File;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;

import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.spi.BuildContext;
import com.widedot.m6809.gamebuilder.spi.configuration.Attribute;

import lombok.extern.slf4j.Slf4j;

/**
 * Handler for the &lt;tilepatch&gt; element : turns a strip of animation
 * frames into the blocks {@code tilemap.patch} writes into a scroll map, plus
 * the descriptor its sequencer reads.
 *
 * <p><b>Why.</b> A scroll map cell is not a tile id but a three byte pointer
 * to the compiled tile's code, baked at build time. Animating scenery is
 * therefore rewriting those pointers in place — which is exactly what the
 * arcade does, repainting a rectangle of its background tilemap to swallow
 * the Outslay into Gomander's tube. Scenery is drawn over sprites, so this is
 * also the only way to make a sprite disappear BEHIND the decor.</p>
 *
 * <p><b>The input</b> is one leanscroll cut of the animation picture, frames
 * laid side by side : a column-major index map of {@code frames * cols}
 * columns by {@code rows} rows. Because the map is column major and the
 * frames are laid horizontally, frame <i>f</i> is a CONTIGUOUS run of
 * {@code cols * rows} indexes — the slicing is a range, not a gather.</p>
 *
 * <p><b>The output</b> mirrors {@link TilemapPlugin} : each index becomes
 * {@code fcb <tiles>$PAGE+$60} then {@code fdb adr_<tiles>_<id>_<variant>},
 * references baked against the tiles' declared placement, so an animation
 * costs no load-time link data. Index 0 keeps its meaning — three zero bytes,
 * the cell draws nothing — which for a patch is a usable effect : it erases
 * what was there.</p>
 *
 * <p>One table of pointers is emitted, not two. The arcade keeps a forward
 * and a reverse table over the same payloads ; the engine sequencer carries
 * the direction as a flag instead, so the data is written once.</p>
 */
@Slf4j
public class TilepatchPlugin {

	public static File getFile(ImmutableNode node, BuildContext ctx) throws Exception {

		String map = ctx.path + File.separator + Attribute.getString(node, ctx, "map");
		// Le plan impair est OPTIONNEL. Le scroll ne lit map.odd que si la
		// parite de la camera l'impose ; un boss qui arrete le defilement fige
		// cette parite, et le plan non lu ne merite ni ses blocs ni ses tuiles.
		// Sans mapodd, le descripteur porte une table nulle et le drain saute
		// ce plan.
		String mapOddRel = Attribute.getStringOpt(node, ctx, "mapodd");
		String mapOdd = mapOddRel == null ? null : ctx.path + File.separator + mapOddRel;
		String label = Attribute.getString(node, ctx, "label");
		String tiles = Attribute.getString(node, ctx, "tiles");
		String tilesOdd = Attribute.getStringOpt(node, ctx, "tilesodd");
		String variant = Attribute.getString(node, ctx, "variant");
		String variantOdd = Attribute.getString(node, ctx, "variantodd", variant);
		String gensymbols = Attribute.getStringOpt(node, ctx, "gensymbols");
		String gensource = ctx.path + File.separator + Attribute.getString(node, ctx, "gensource");
		String section = Attribute.getString(node, ctx, "section", "map");
		int bitdepth = Attribute.getInteger(node, ctx, "bitdepth", 16);
		int cols = Attribute.getInteger(node, ctx, "cols");
		int rows = Attribute.getInteger(node, ctx, "rows");
		int frames = Attribute.getInteger(node, ctx, "frames");
		int dstCol = Attribute.getInteger(node, ctx, "col", 0);
		int dstRow = Attribute.getInteger(node, ctx, "row", 0);
		int hold = Attribute.getInteger(node, ctx, "hold", 1);
		// `first` lets several animations share ONE leanscroll cut, hence one
		// tileset : the strip holds every frame of every animation side by
		// side, and each <tilepatch> takes its own window of it. Four tube
		// openings in one tileset instead of four is worth the attribute.
		int first = Attribute.getInteger(node, ctx, "first", 0);
		// `firstcol` fait le meme travail que `first` mais en COLONNES de la
		// bande : indispensable des que les animations partageant une coupe
		// n'ont pas toutes la meme largeur (les quatre tubes du gomander font
		// 2, 3, 2 et 4 colonnes — un compte de trames ne tombe plus juste).
		int firstcol = Attribute.getInteger(node, ctx, "firstcol", -1);
		// `base` fait de la TRAME 0 les cellules du niveau lui-meme : la carte
		// donnee est lue au rectangle de destination et pointee telle quelle,
		// comme <tilereset> — rien n'est compile deux fois. C'est la trame
		// « repos » d'un clignotement : alterner 0/1 flashe puis remet le
		// decor, et finir sur 0 rend l'ecran exactement comme avant.
		String baseRel = Attribute.getStringOpt(node, ctx, "base");
		String basetiles = Attribute.getStringOpt(node, ctx, "basetiles");
		String basevariant = Attribute.getString(node, ctx, "basevariant", variant);
		int baserows = Attribute.getInteger(node, ctx, "baserows", 0);

		if (bitdepth != 8 && bitdepth != 16) {
			throw new Exception("tilepatch " + label + " : bitdepth must be 8 or 16");
		}
		if (cols < 1 || rows < 1 || frames < 1) {
			throw new Exception("tilepatch " + label + " : cols, rows and frames must all be at least 1");
		}
		// The sequencer adds `hold` to a late clock until it turns positive ;
		// a hold of zero would spin there for ever. Refuse it here, where the
		// author can still read the message.
		if (hold < 1 || hold > 255) {
			throw new Exception("tilepatch " + label + " : hold is " + hold
					+ ", it must be between 1 and 255 (video frames per animation frame)");
		}
		if (dstCol < 0 || dstCol > 255 || dstRow < 0 || dstRow > 255
				|| cols > 255 || rows > 255 || frames > 255) {
			throw new Exception("tilepatch " + label + " : geometry and destination are single bytes at run time");
		}

		byte[] data = Files.readAllBytes(Paths.get(map));
		if ((mapOdd == null) != (tilesOdd == null)) {
			throw new Exception("tilepatch " + label + " : mapodd and tilesodd go together");
		}
		byte[] dataOdd = mapOdd == null ? data : Files.readAllBytes(Paths.get(mapOdd));
		if (data.length != dataOdd.length) {
			throw new Exception("tilepatch " + label + " : the two planes hold "
					+ data.length + " and " + dataOdd.length + " bytes — they describe"
					+ " the same animation, so they must have the same shape");
		}
		int step = bitdepth / 8;
		if (data.length % step != 0) {
			throw new Exception("tilepatch " + label + " : " + map + " is " + data.length
					+ " bytes, not a whole number of " + bitdepth + " bit indexes");
		}
		int entries = data.length / step;
		if ((baseRel == null) != (basetiles == null)) {
			throw new Exception("tilepatch " + label + " : base and basetiles go together");
		}
		if (baseRel != null && baserows < 1) {
			throw new Exception("tilepatch " + label + " : base needs baserows (rows per column of that map)");
		}
		if (baseRel != null && mapOdd != null) {
			throw new Exception("tilepatch " + label + " : base only supports the even plane");
		}
		int stripFrames = frames - (baseRel == null ? 0 : 1);
		if (stripFrames < 1) {
			throw new Exception("tilepatch " + label + " : frames counts the base frame too, it must be at least 2 with base");
		}
		int base0 = firstcol >= 0 ? firstcol * rows : first * cols * rows;
		int need = base0 + stripFrames * cols * rows;
		if (entries < need) {
			throw new Exception("tilepatch " + label + " : " + map + " holds " + entries
					+ " indexes, but the window starting at cell " + base0
					+ " needs " + need + " for " + stripFrames + " frames of " + cols + "x" + rows
					+ " — the picture and the declared geometry disagree");
		}

		int[] ids = new int[entries];
		int[] idsOdd = new int[entries];
		java.util.TreeSet<Integer> used = new java.util.TreeSet<Integer>();
		java.util.TreeSet<Integer> usedOdd = new java.util.TreeSet<Integer>();
		for (int i = 0; i < entries; i++) {
			ids[i] = step == 1 ? data[i] & 0xFF
					: ((data[i * 2] & 0xFF) << 8) | (data[i * 2 + 1] & 0xFF);
			idsOdd[i] = step == 1 ? dataOdd[i] & 0xFF
					: ((dataOdd[i * 2] & 0xFF) << 8) | (dataOdd[i * 2 + 1] & 0xFF);
			// seule LA FENETRE de cette animation compte : `first` permet a
			// plusieurs <tilepatch> de partager une coupe, et declarer les
			// tuiles des autres fausserait le releve autant que le fichier.
			boolean mine = i >= base0 && i < base0 + stripFrames * cols * rows;
			if (mine && ids[i] != 0) used.add(ids[i]);
			if (mine && mapOdd != null && idsOdd[i] != 0) usedOdd.add(idsOdd[i]);
		}

		int[] baseIds = null;
		java.util.TreeSet<Integer> usedBase = new java.util.TreeSet<Integer>();
		if (baseRel != null) {
			byte[] bd = Files.readAllBytes(Paths.get(ctx.path + File.separator + baseRel));
			baseIds = new int[cols * rows];
			for (int c = 0; c < cols; c++) {
				for (int r = 0; r < rows; r++) {
					int i = (dstCol + c) * baserows + (dstRow + r);
					int id = step == 1 ? bd[i] & 0xFF
							: ((bd[i * 2] & 0xFF) << 8) | (bd[i * 2 + 1] & 0xFF);
					baseIds[c * rows + r] = id;
					if (id != 0) usedBase.add(id);
				}
			}
		}

		com.widedot.m6809.gamebuilder.spi.globals.Machines.Machine machine =
				ctx.machines.required("<tilepatch>");

		StringBuilder source = new StringBuilder();
		String nl = System.lineSeparator();
		source.append("* Generated by tilepatch from ").append(map).append(nl);
		source.append("* and ").append(mapOdd).append(nl);
		source.append("* ").append(frames).append(" frames of ").append(cols).append('x').append(rows)
				.append(" cells, column major").append(nl);
		source.append("        INCLUDE \"").append(machine.pageInclude).append('"').append(nl);
		for (int id : used) {
			String tile = "adr_" + tiles + "_" + id + "_" + variant;
			source.append(tile).append(" EXTERNAL").append(nl);
			source.append(tile).append("$PAGE EXTERNAL").append(nl);
		}
		for (int id : usedOdd) {
			String tile = "adr_" + tilesOdd + "_" + id + "_" + variantOdd;
			source.append(tile).append(" EXTERNAL").append(nl);
			source.append(tile).append("$PAGE EXTERNAL").append(nl);
		}
		for (int id : usedBase) {
			String tile = "adr_" + basetiles + "_" + id + "_" + basevariant;
			source.append(tile).append(" EXTERNAL").append(nl);
			source.append(tile).append("$PAGE EXTERNAL").append(nl);
		}
		source.append(label).append(" EXPORT").append(nl);
		source.append(" SECTION ").append(section).append(nl);

		// ONE descriptor carrying BOTH planes. They describe the same animation
		// at the same place and differ only in the tiles they name, so splitting
		// them would force every consumer to carry a pair — and a deferred
		// request would be five bytes instead of three.
		source.append(label).append(nl);
		source.append("        fcb   ").append(cols).append("        ; cols").append(nl);
		source.append("        fcb   ").append(rows).append("        ; rows").append(nl);
		source.append("        fcb   ").append(frames).append("        ; frames").append(nl);
		source.append("        fcb   ").append(dstCol).append("        ; destination column").append(nl);
		source.append("        fcb   ").append(dstRow).append("        ; destination row").append(nl);
		source.append("        fcb   ").append(hold).append("        ; video frames per animation frame").append(nl);
		source.append("        fdb   ").append(label).append(".tableEven").append(nl);
		if (mapOdd == null) {
			source.append("        fdb   0        ; pas de plan impair").append(nl);
		} else {
			source.append("        fdb   ").append(label).append(".tableOdd").append(nl);
		}

		int empty = 0;
		for (int plane = 0; plane < (mapOdd == null ? 1 : 2); plane++) {
			int[] src = (plane == 0) ? ids : idsOdd;
			String host = (plane == 0) ? tiles : tilesOdd;
			String var = (plane == 0) ? variant : variantOdd;
			String suffix = (plane == 0) ? "Even" : "Odd";
			source.append(label).append(".table").append(suffix).append(nl);
			for (int f = 0; f < frames; f++) {
				source.append("        fdb   ").append(label).append('.').append(suffix)
						.append(f).append(nl);
			}
			for (int f = 0; f < frames; f++) {
				source.append(label).append('.').append(suffix).append(f).append(nl);
				boolean fromBase = baseIds != null && f == 0;
				int base = base0 + (f - (baseIds == null ? 0 : 1)) * cols * rows;
				String h = fromBase ? basetiles : host;
				String v = fromBase ? basevariant : var;
				for (int i = 0; i < cols * rows; i++) {
					int id = fromBase ? baseIds[i] : src[base + i];
					if (id == 0) {
						// same convention as <tilemap> : nothing to draw. On a
						// patch that is not a hole in the data, it is an erase.
						source.append("        fcb   0").append(nl);
						source.append("        fdb   0").append(nl);
						empty++;
						continue;
					}
					String symbol = "adr_" + h + "_" + id + "_" + v;
					source.append("        fcb   ").append(machine.pageExpr).append(symbol)
							.append("$PAGE").append(nl);
					source.append("        fdb   ").append(symbol).append(nl);
				}
			}
		}
		source.append(" ENDSECTION").append(nl);

		Path path = Paths.get(gensource);
		if (path.getParent() != null) {
			Files.createDirectories(path.getParent());
		}
		Files.writeString(path, source.toString());

		// The geometry as ASSEMBLY-TIME equates, for the object that drives the
		// animation. It needs the frame count and the hold to run its clock, and
		// they live in the descriptor — which sits in the map's page. Reading
		// them at run time would drag paging back into object code ; generated
		// from the same source as the data, they cannot drift either.
		if (gensymbols != null) {
			StringBuilder eq = new StringBuilder();
			String guard = label.toUpperCase().replaceAll("[^A-Z0-9]", "_") + "_CONST";
			eq.append("* Generated by tilepatch — geometry of ").append(label).append(nl);
			eq.append(" IFNDEF ").append(guard).append(nl);
			eq.append(guard).append(" equ 1").append(nl);
			eq.append(label).append(".FRAMES equ ").append(frames).append(nl);
			eq.append(label).append(".HOLD   equ ").append(hold).append(nl);
			eq.append(label).append(".COLS   equ ").append(cols).append(nl);
			eq.append(label).append(".ROWS   equ ").append(rows).append(nl);
			eq.append(" ENDC").append(nl);
			Path ep = Paths.get(ctx.path + File.separator + gensymbols);
			if (ep.getParent() != null) {
				Files.createDirectories(ep.getParent());
			}
			Files.writeString(ep, eq.toString());
		}

		// entries est la bande ENTIERE, partagee entre plusieurs animations :
		// le cout de celle-ci est sa fenetre a elle, base comprise.
		log.info("tilepatch {} : {} frames of {}x{} over two planes ({}+{} distinct tiles, "
				+ "{} empty cells), {} bytes of blocks + {} of tables and descriptor",
				label, frames, cols, rows, used.size(), usedOdd.size(), empty,
				frames * cols * rows * 3 * (mapOdd == null ? 1 : 2),
				frames * 2 * (mapOdd == null ? 1 : 2) + 8);
		return path.toFile();
	}
}
