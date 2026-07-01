package com.widedot.toolbox.debug;

import com.sun.jna.Memory;
import com.sun.jna.Platform;
import com.widedot.toolbox.debug.os.MacProcess;
import com.widedot.toolbox.debug.os.NativeProcess;
import com.widedot.toolbox.debug.os.WindowsProcess;

/**
 * Facade over the platform-specific {@link NativeProcess} backend. Callers use
 * these static methods without caring whether they run on Windows or macOS.
 */
public class OS {

	private static final NativeProcess IMPL = create();

	private static NativeProcess create() {
		if (Platform.isWindows()) {
			return new WindowsProcess();
		}
		if (Platform.isMac()) {
			return new MacProcess();
		}
		return null; // unsupported platform: methods below degrade gracefully
	}

	public static int getProcessId(String name) {
		return IMPL == null ? 0 : IMPL.findPid(name);
	}

	public static boolean openProcess(int pid) {
		return IMPL != null && IMPL.open(pid);
	}

	public static long findSignature(byte[] key, int keyPos) {
		return IMPL == null ? 0 : IMPL.findSignature(key, keyPos);
	}

	public static long findBytes(byte[] pattern, byte[] mask) {
		return IMPL == null ? 0 : IMPL.findBytes(pattern, mask);
	}

	public static Memory readMemory(long address, int length) {
		return IMPL == null ? null : IMPL.read(address, length);
	}

	public static void writeMemory(long address, byte[] data) {
		if (IMPL != null) {
			IMPL.write(address, data);
		}
	}
}
