package com.widedot.toolbox.debug.os;

import java.nio.ByteBuffer;

import com.sun.jna.Memory;
import com.sun.jna.NativeLibrary;
import com.sun.jna.Pointer;
import com.sun.jna.ptr.IntByReference;
import com.sun.jna.ptr.LongByReference;

/**
 * macOS backend: attaches to the emulator via Mach APIs.
 * <p>
 * Under Wine, {@code dcmoto*.exe} runs as a native macOS task, so its emulated
 * Thomson RAM is plain bytes in the process address space, reachable through
 * {@code task_for_pid} + {@code mach_vm_read_overwrite}. Reading another process
 * requires either root or a binary signed with the
 * {@code com.apple.security.cs.debugger} entitlement (same model as lldb);
 * SIP does not need to be disabled for a same-user target.
 */
public class MacProcess implements NativeProcess {

	private static final long CHUNK = 16L * 1024 * 1024;
	private static final long MAX_REGION = 1L << 32; // skip huge reserved (Wine) regions

	private final SystemB sb = SystemB.INSTANCE;
	private final int selfTask = NativeLibrary.getInstance("System")
			.getGlobalVariableAddress("mach_task_self_").getInt(0);

	private int task = 0;

	@Override
	public int findPid(String nameContains) {
		int bytes = sb.proc_listpids(SystemB.PROC_ALL_PIDS, 0, Pointer.NULL, 0);
		if (bytes <= 0) {
			return 0;
		}
		Memory buf = new Memory(bytes);
		int got = sb.proc_listpids(SystemB.PROC_ALL_PIDS, 0, buf, (int) buf.size());
		int n = got / 4;
		Memory path = new Memory(4096);
		int fallback = 0;
		for (int i = 0; i < n; i++) {
			int pid = buf.getInt((long) i * 4);
			if (pid == 0) {
				continue;
			}
			int len = sb.proc_pidpath(pid, path, (int) path.size());
			if (len <= 0) {
				continue;
			}
			// match on the full path: under Wine the short comm name may be the
			// wine preloader, but the .exe path still contains the emulator name.
			String p = new String(path.getByteArray(0, len));
			if (p.contains(nameContains)) {
				// prefer the Wine executable itself over app wrappers / helpers
				// (e.g. the Sikarugir launcher path also contains "dcmoto").
				if (p.endsWith(".exe")) {
					return pid;
				}
				if (fallback == 0) {
					fallback = pid;
				}
			}
		}
		return fallback;
	}

	@Override
	public boolean open(int pid) {
		IntByReference t = new IntByReference();
		int kr = sb.task_for_pid(selfTask, pid, t);
		if (kr != 0) {
			task = 0;
			return false;
		}
		task = t.getValue();
		return true;
	}

	@Override
	public long findSignature(byte[] key, int keyPos) {
		long a = findBytes(key, null);
		return a == 0 ? 0 : a - keyPos;
	}

	@Override
	public long findBytes(byte[] pattern, byte[] mask) {
		if (task == 0) {
			return 0;
		}
		long addr = 0;
		LongByReference addrRef = new LongByReference(0);
		LongByReference sizeRef = new LongByReference(0);
		Memory info = new Memory(256);
		Memory chunk = new Memory(CHUNK);
		while (true) {
			addrRef.setValue(addr);
			IntByReference cnt = new IntByReference(SystemB.VM_REGION_BASIC_INFO_COUNT_64);
			IntByReference objName = new IntByReference();
			int kr = sb.mach_vm_region(task, addrRef, sizeRef,
					SystemB.VM_REGION_BASIC_INFO_64, info, cnt, objName);
			if (kr != 0) {
				break; // end of address space
			}
			long base = addrRef.getValue();
			long size = sizeRef.getValue();
			if (size <= 0) {
				break;
			}
			if (size <= MAX_REGION) {
				long found = scanRegion(chunk, base, size, pattern, mask);
				if (found != 0) {
					return found;
				}
			}
			addr = base + size;
		}
		return 0;
	}

	private long scanRegion(Memory chunk, long base, long size, byte[] pattern, byte[] mask) {
		long p = base;
		long remaining = size;
		while (remaining > 0) {
			long want = Math.min(remaining, chunk.size());
			LongByReference outSize = new LongByReference(0);
			int kr = sb.mach_vm_read_overwrite(task, p, want, Pointer.nativeValue(chunk), outSize);
			if (kr != 0) {
				return 0; // region not (fully) readable -> skip
			}
			long got = outSize.getValue();
			if (got <= 0) {
				return 0;
			}
			ByteBuffer bb = chunk.getByteBuffer(0, got);
			for (long i = 0; i + pattern.length <= got; i++) {
				boolean found = true;
				for (int j = 0; j < pattern.length; j++) {
					int m = mask == null ? 0xff : (mask[j] & 0xff);
					if ((bb.get((int) (i + j)) & m) != (pattern[j] & m)) {
						found = false;
						break;
					}
				}
				if (found) {
					return p + i;
				}
			}
			// overlap by pattern.length-1 so a match split across chunks is still found
			long step = got - (pattern.length - 1);
			if (step <= 0) {
				break;
			}
			p += step;
			remaining -= step;
		}
		return 0;
	}

	@Override
	public Memory read(long address, int length) {
		if (task == 0) {
			return null;
		}
		Memory out = new Memory(length);
		out.clear();
		LongByReference outSize = new LongByReference(0);
		// On failure (unreadable / transiently unmapped address) return the
		// zero-filled buffer rather than null, matching Windows ReadProcessMemory
		// so callers that don't null-check (e.g. Emulator.get) don't crash.
		sb.mach_vm_read_overwrite(task, address, length, Pointer.nativeValue(out), outSize);
		return out;
	}

	@Override
	public void write(long address, byte[] data) {
		if (task == 0) {
			return;
		}
		Memory buf = new Memory(data.length);
		buf.write(0, data, 0, data.length);
		sb.mach_vm_write(task, address, buf, data.length);
	}
}
