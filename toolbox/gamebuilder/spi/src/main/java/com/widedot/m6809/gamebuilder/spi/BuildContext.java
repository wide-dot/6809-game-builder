package com.widedot.m6809.gamebuilder.spi;

import com.widedot.m6809.gamebuilder.spi.configuration.Defaults;
import com.widedot.m6809.gamebuilder.spi.configuration.Defines;
import com.widedot.m6809.gamebuilder.spi.configuration.Settings;
import com.widedot.m6809.gamebuilder.spi.configuration.SourceMap;
import com.widedot.m6809.gamebuilder.spi.globals.FileIds;
import com.widedot.m6809.gamebuilder.spi.globals.LinkSymbols;

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

	/** inherited attribute defaults, scoped to this container */
	public final Defaults defaults;

	/** assembler defines, scoped to this container */
	public final Defines defines;

	public BuildContext(String path, Settings settings) {
		this(path, settings, new SourceMap("<memory>"));
	}

	public BuildContext(String path, Settings settings, SourceMap sources) {
		this(path, settings, sources, new LinkSymbols(), new FileIds(), new Defaults(), new Defines());
	}

	private BuildContext(String path, Settings settings, SourceMap sources, LinkSymbols linkSymbols,
			FileIds fileIds, Defaults defaults, Defines defines) {
		this.path = path;
		this.settings = settings;
		this.sources = sources;
		this.linkSymbols = linkSymbols;
		this.fileIds = fileIds;
		this.defaults = defaults;
		this.defines = defines;
	}

	/**
	 * @return a context for a nested container: its own defaults and defines,
	 *         everything else shared
	 */
	public BuildContext child() {
		return new BuildContext(path, settings, sources, linkSymbols, fileIds,
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
		defaults.values.clear();
		defines.values.clear();
		defines.newValues.clear();
	}
}
