package com.widedot.m6809.gamebuilder.spi.globals;

/**
 * How a file's references are resolved, declared in the configuration —
 * never in the source. The source says WHAT a unit references
 * ({@code EXPORT}/{@code EXTERNAL}) ; the configuration says WHERE everything
 * lives ; the mode says which of the two resolvers closes the gap.
 *
 * <ul>
 *   <li>{@code NONE} — everything through the load-time linker. The default.</li>
 *   <li>{@code AUTO} — each reference is classified : baked when its provider
 *       sits at one fixed destination the consumer can see (interns, when the
 *       unit itself does), left load-time linked otherwise — references into
 *       run-time alternatives stay linked by construction. An optimiser, not
 *       a promise.</li>
 *   <li>{@code ALL} — the strict promise the {@code *.static} sections used to
 *       carry : every reference must bake, a failure is a build error naming
 *       the symbol and the cause. For generated tables and fully-fixed
 *       units, where a silent fallback would hide a regression.</li>
 * </ul>
 */
public enum BakeMode {
	NONE, AUTO, ALL;

	public static BakeMode parse(String value) throws Exception {
		if (value == null || value.isBlank() || value.equals("none")) return NONE;
		if (value.equals("auto")) return AUTO;
		if (value.equals("all"))  return ALL;
		throw new Exception("bake='" + value + "' is not one of none, auto, all");
	}
}
