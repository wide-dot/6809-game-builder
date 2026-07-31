package com.widedot.m6809.gamebuilder.spi.globals;

/**
 * Global file id allocator.
 *
 * File ids are allocated continuously across every directory of a target,
 * instead of restarting at 0 on each disk. The runtime identifies a file by
 * its id alone in several places (loader.file.getPageID, externPg
 * relocations, link data symbol lookups), and the link data format has no
 * room for a disk qualifier : per-disk numbering made those ids ambiguous as
 * soon as two disks were indexed at the same time.
 *
 * Each directory records the id of its first entry in its header, so the
 * loader can turn a global id back into an index in the current directory.
 */
public class FileIds {

	public int next = 0;

	/**
	 * @return the id allocated to the next directory entry, and reserve it
	 */
	public int allocate() {
		return next++;
	}

	/**
	 * @return the id that will be allocated next, without reserving it
	 */
	public int peek() {
		return next;
	}

	public void clear() {
		next = 0;
	}
}
