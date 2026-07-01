package com.widedot.toolbox.debug.os;

import com.sun.jna.Memory;

/**
 * Platform-independent access to the memory of a running emulator process.
 * <p>
 * wddebug does not emulate anything: it attaches to a live emulator (DCMOTO / Teo)
 * and reads (optionally writes) its address space. The Windows and macOS backends
 * implement this the same way conceptually - find the process, acquire a handle,
 * locate the emulated RAM by scanning for a known signature, then peek/poke - but
 * on top of completely different native APIs (Win32 Toolhelp/ReadProcessMemory vs
 * Mach task_for_pid/mach_vm_read).
 */
public interface NativeProcess {

	/** @return pid of the first process whose name/path contains {@code nameContains}, or 0 if none. */
	int findPid(String nameContains);

	/** Acquire a handle (Win32 HANDLE / Mach task port) on the given pid. @return true on success. */
	boolean open(int pid);

	/**
	 * Locate the emulated RAM block by scanning the process memory for {@code key}.
	 * @param keyPos offset of the signature inside the RAM block (subtracted from the match).
	 * @return absolute base address of the emulated RAM, or 0 if the signature was not found.
	 */
	long findSignature(byte[] key, int keyPos);

	/**
	 * Find the first occurrence of {@code pattern} in the process memory.
	 * @param mask per-byte AND mask (same length as pattern); null means exact match.
	 *             A mask byte of 0x0F matches only the low nibble, 0x00 ignores the byte.
	 * @return absolute address of the match, or 0 if not found.
	 */
	long findBytes(byte[] pattern, byte[] mask);

	/** Read {@code length} bytes at {@code address} into an off-heap buffer, or null on failure. */
	Memory read(long address, int length);

	/** Write {@code data} at {@code address} (poke). No-op if not attached. */
	void write(long address, byte[] data);
}
