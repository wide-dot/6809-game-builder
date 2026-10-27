package com.widedot.toolbox.graphics.spritestream;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.TreeMap;

import org.apache.commons.configuration2.tree.ImmutableNode;

import com.widedot.m6809.gamebuilder.spi.BuildContext;
import com.widedot.m6809.gamebuilder.spi.configuration.Attribute;

/**
 * The shape set : what the streams may hold and what the walkers draw. The
 * streams and the walkers of a build must be made with the same options (set
 * them once with {@code <default name="spritestream.xxx">}) : a stream holds
 * record codes, the walkers' jump tables give them a meaning.
 *
 * Codes : 0 end, 2 nop (a row down, for a delta too long for a byte), then
 * 2 + 2 i for the i-th shape, in this order : masked single-row segments of
 * 1 to segment bytes (first byte on plane 0, then plane 1), the multi-row
 * ones by length then rows then plane, the opaque ones.
 */
public final class Options {

	public static final String VIDEOMODE = "bm4s";

	/** at most 64 codes : the stored walk indexes its jump table with a signed A */
	static final int MAX_CODES = 64;

	final int segment;
	/** segment length -> most rows of a multi-row masked record */
	final Map<Integer, Integer> rows;
	final boolean mirrorable;
	final boolean save;
	final boolean opaque;
	final boolean mergePulls;
	final boolean clip;
	final List<Shape> shapes = new ArrayList<Shape>();
	final List<String> names = new ArrayList<String>();

	Options(int segment, Map<Integer, Integer> rows, boolean mirrorable, boolean save, boolean opaque,
			boolean mergePulls, boolean clip) throws Exception {
		if (segment < 1 || segment > 16) {
			throw new Exception("segment must be 1 to 16 bytes, got " + segment);
		}
		this.segment = segment;
		this.rows = Collections.unmodifiableMap(new TreeMap<Integer, Integer>(rows));
		this.mirrorable = mirrorable;
		this.save = save;
		this.opaque = opaque;
		this.mergePulls = mergePulls;
		this.clip = clip;
		for (Map.Entry<Integer, Integer> e : this.rows.entrySet()) {
			if (e.getKey() < 1 || e.getKey() > segment || e.getValue() < 1) {
				throw new Exception("rows : " + e.getKey() + ":" + e.getValue() + " is not a segment length"
						+ " of 1 to " + segment + " with at least 1 row");
			}
		}
		for (int p = 0; p < 2; p++) {
			for (int n = 1; n <= segment; n++) {
				shapes.add(new Shape(p, n, 1, false));
			}
		}
		for (Map.Entry<Integer, Integer> e : this.rows.entrySet()) {
			for (int r = 2; r <= e.getValue(); r++) {
				for (int p = 0; p < 2; p++) {
					shapes.add(new Shape(p, e.getKey(), r, false));
				}
			}
		}
		if (opaque) {
			for (int p = 0; p < 2; p++) {
				for (int n = 1; n <= segment; n++) {
					shapes.add(new Shape(p, n, 1, true));
				}
			}
		}
		names.add("end");
		names.add("nop");
		for (Shape s : shapes) {
			names.add(s.name());
		}
		if (names.size() > MAX_CODES) {
			throw new Exception(names.size() + " record codes, past " + MAX_CODES
					+ " : fewer multi-row records or a shorter segment");
		}
	}

	/** the options of a {@code <spritestream>} element, through the defaults cascade */
	static Options of(ImmutableNode node, BuildContext ctx) throws Exception {
		String mode = Attribute.getString(node, ctx, "videomode", VIDEOMODE);
		if (!VIDEOMODE.equals(mode)) {
			throw new Exception("<spritestream videomode> : '" + mode + "' is not supported, only " + VIDEOMODE);
		}
		int segment = Attribute.getInteger(node, ctx, "segment", 6);
		Map<Integer, Integer> rows = parseRows(Attribute.getString(node, ctx, "rows", "2:2,3:2"));
		boolean mirrorable = Attribute.getBoolean(node, ctx, "mirrorable", true);
		boolean save = Attribute.getBoolean(node, ctx, "save", true);
		boolean opaque = Attribute.getBoolean(node, ctx, "opaque", false);
		boolean merge = Attribute.getBoolean(node, ctx, "mergepulls", true);
		boolean clip = Attribute.getBoolean(node, ctx, "clip", false);
		return new Options(segment, rows, mirrorable, save, opaque, merge, clip);
	}

	/** "2:2,3:2" : segment length : most rows ; empty for none */
	static Map<Integer, Integer> parseRows(String s) throws Exception {
		Map<Integer, Integer> out = new TreeMap<Integer, Integer>();
		for (String item : s.split("[,\\s]+")) {
			if (item.isEmpty() || "none".equals(item)) {
				continue;
			}
			String[] f = item.split(":");
			if (f.length != 2) {
				throw new Exception("rows : '" + item + "' is not <bytes>:<rows>");
			}
			try {
				out.put(Integer.parseInt(f[0].trim()), Integer.parseInt(f[1].trim()));
			} catch (NumberFormatException e) {
				throw new Exception("rows : '" + item + "' is not <bytes>:<rows>");
			}
		}
		return out;
	}

	/** the record code of a name (end, nop or a shape) */
	int code(String name) {
		int i = names.indexOf(name);
		if (i < 0) {
			throw new IllegalArgumentException("no record code " + name);
		}
		return 2 * i;
	}

	int code(Shape s) {
		return code(s.name());
	}

	/** the shape of a code, null for end and nop */
	Shape shape(int code) {
		int i = code / 2;
		return i < 2 ? null : shapes.get(i - 2);
	}

	/** the longest multi-row masked record for segments of n bytes */
	int maxRows(int n) {
		Integer r = rows.get(n);
		return r == null ? 1 : r;
	}

	/** a one-line summary, written at the head of the generated sources */
	String describe() {
		StringBuilder sb = new StringBuilder();
		sb.append("segment=").append(segment).append(" rows=");
		if (rows.isEmpty()) {
			sb.append("none");
		}
		String sep = "";
		for (Map.Entry<Integer, Integer> e : rows.entrySet()) {
			sb.append(sep).append(e.getKey()).append(':').append(e.getValue());
			sep = ",";
		}
		sb.append(" mirrorable=").append(mirrorable).append(" save=").append(save).append(" opaque=")
				.append(opaque);
		return sb.toString();
	}
}
