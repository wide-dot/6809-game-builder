package com.widedot.m6809.gamebuilder.plugin.scene;

import java.util.ArrayList;
import java.util.List;

/**
 * What one scene declared, kept for the verification pass that runs once all
 * the directory entries are built and their sizes are known.
 */
public class SceneCheck {

	public enum Kind {
		/** a destination of its own : a region, an arena slot, or a raw page/address */
		PLACED,
		/** no destination : link data only */
		EXPORT_ONLY
	}

	public static class Load {
		public final String name;
		public final Kind kind;
		/** destination ; 0 for export-only */
		public final int page;
		public final int address;
		/** region byte budget, null when none declared or raw destination */
		public final Integer budget;
		/** region name for messages, null for raw destinations */
		public final String region;
		/** source position of the load element */
		public final String where;

		public Load(String name, Kind kind, int page, int address, Integer budget,
				String region, String where) {
			this.name = name;
			this.kind = kind;
			this.page = page;
			this.address = address;
			this.budget = budget;
			this.region = region;
			this.where = where;
		}
	}

	public final String sceneName;
	public final List<Load> loads = new ArrayList<Load>();

	public SceneCheck(String sceneName) {
		this.sceneName = sceneName;
	}
}
