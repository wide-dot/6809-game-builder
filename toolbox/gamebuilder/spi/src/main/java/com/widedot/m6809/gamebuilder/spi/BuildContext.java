package com.widedot.m6809.gamebuilder.spi;

import com.widedot.m6809.gamebuilder.spi.configuration.Defaults;
import com.widedot.m6809.gamebuilder.spi.configuration.Defines;
import com.widedot.m6809.gamebuilder.spi.configuration.Settings;
import com.widedot.m6809.gamebuilder.spi.configuration.SourceMap;
import com.widedot.m6809.gamebuilder.spi.globals.FileIds;
import com.widedot.m6809.gamebuilder.spi.globals.FilePlaces;
import com.widedot.m6809.gamebuilder.spi.globals.ImageSets;
import com.widedot.m6809.gamebuilder.spi.globals.LinkReport;
import com.widedot.m6809.gamebuilder.spi.globals.LinkSymbols;
import com.widedot.m6809.gamebuilder.spi.globals.Occupancy;
import com.widedot.m6809.gamebuilder.spi.globals.Outputs;
import com.widedot.m6809.gamebuilder.spi.globals.PageSets;
import com.widedot.m6809.gamebuilder.spi.globals.RamMap;
import com.widedot.m6809.gamebuilder.spi.globals.Regions;
import com.widedot.m6809.gamebuilder.spi.globals.StaticLink;

/**
 * Everything a plugin needs to run: where the build is rooted, its settings,
 * and the state it shares with the rest of the build.
 *
 * This used to be static fields plus four parameters threaded by hand through
 * every plugin. Holding it in one object makes the build reentrant — two
 * configurations can be processed in the same JVM without leaking ids or
 * defines into one another — and lets a test build one without a JVM-wide
 * setup.
 *
 * Defaults and defines are *scoped*: a container forks a child context, the
 * child accumulates its own values, and publishing merges what the child
 * declared back into the parent. Everything else is shared by reference for
 * the whole build.
 */
public class BuildContext {

	/** directory of the configuration file, base for every relative path */
	public final String path;

	public final Settings settings;

	/** source positions of the configuration tree, for error messages */
	public final SourceMap sources;

	/** link symbol ids and export ownership, shared across a target */
	public final LinkSymbols linkSymbols;

	/** file id allocator, shared across a target */
	public final FileIds fileIds;

	/** memory layout declared by the target, referenced by scene loads */
	public final Regions regions;

	/** build-time resolution registry for the sections named *.static */
	public final StaticLink staticLink;

	/** datasets spread over the pages of a multi-page region, and their members */
	public final PageSets pageSets;

	/** destinations declared on the <file> elements themselves, by file name */
	public final FilePlaces filePlaces;

	/** imageset geometry a <gfxcomp> hands to the <imageset> that indexes it */
	public final ImageSets imageSets;

	/** what each file costs in link data, reported at the end of a target */
	public final LinkReport linkReport;

	/** what each scene puts in memory, mapped at the end of a target */
	public final RamMap ramMap;

	/** what the build physically wrote, for the occupancy report */
	public final Occupancy occupancy;

	/** distributable files written by this target, discarded if it fails */
	public final Outputs outputs;

	/** inherited attribute defaults, scoped to this container */
	public final Defaults defaults;

	/** assembler defines, scoped to this container */
	public final Defines defines;

	public BuildContext(String path, Settings settings) {
		this(path, settings, new SourceMap("<memory>"));
	}

	public BuildContext(String path, Settings settings, SourceMap sources) {
		this(path, settings, sources, new LinkSymbols(), new FileIds(), new Regions(), new StaticLink(), new PageSets(), new FilePlaces(), new ImageSets(), new LinkReport(), new RamMap(), new Occupancy(), new Outputs(), new Defaults(), new Defines());
	}

	private BuildContext(String path, Settings settings, SourceMap sources, LinkSymbols linkSymbols,
			FileIds fileIds, Regions regions, StaticLink staticLink, PageSets pageSets,
			FilePlaces filePlaces, ImageSets imageSets, LinkReport linkReport, RamMap ramMap, Occupancy occupancy,
			Outputs outputs, Defaults defaults, Defines defines) {
		this.path = path;
		this.settings = settings;
		this.sources = sources;
		this.linkSymbols = linkSymbols;
		this.fileIds = fileIds;
		this.regions = regions;
		this.staticLink = staticLink;
		this.pageSets = pageSets;
		this.filePlaces = filePlaces;
		this.imageSets = imageSets;
		this.linkReport = linkReport;
		this.ramMap = ramMap;
		this.occupancy = occupancy;
		this.outputs = outputs;
		this.defaults = defaults;
		this.defines = defines;
		// export uniqueness is relaxed between direntries the scenes make
		// mutually exclusive ; the symbol table asks the placements for that
		this.linkSymbols.placements = staticLink;
	}

	/**
	 * @return a context for a nested container: its own defaults and defines,
	 *         everything else shared
	 */
	public BuildContext child() {
		return new BuildContext(path, settings, sources, linkSymbols, fileIds, regions, staticLink,
				pageSets, filePlaces, imageSets, linkReport, ramMap, occupancy, outputs,
				new Defaults(defaults.values), new Defines(defines.values));
	}

	/** Merges back what a child container declared. */
	public void publish(BuildContext child) {
		defines.publish(child.defines);
	}

	/**
	 * Resets the state that must not survive from one target to the next, so
	 * that building "-t fd" alone and "-t sd,fd" produce the same images.
	 */
	public void resetTarget() {
		fileIds.clear();
		linkSymbols.clear();
		regions.clear();
		staticLink.clear();
		pageSets.clear();
		filePlaces.clear();
		imageSets.clear();
		linkReport.clear();
		ramMap.clear();
		occupancy.clear();
		outputs.clear();
		defaults.values.clear();
		defines.values.clear();
		defines.newValues.clear();
	}
}
