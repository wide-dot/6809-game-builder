package com.widedot.toolbox.debug.os;

import java.nio.ByteBuffer;

import com.sun.jna.Memory;
import com.sun.jna.Native;
import com.sun.jna.Pointer;
import com.sun.jna.platform.win32.Tlhelp32;
import com.sun.jna.platform.win32.WinDef;
import com.sun.jna.platform.win32.WinNT;
import com.sun.jna.ptr.IntByReference;
import com.sun.jna.win32.W32APIOptions;

/**
 * Windows backend: attaches to the emulator via the Toolhelp32 snapshot API and
 * ReadProcessMemory / WriteProcessMemory. This is the original wddebug behaviour,
 * unchanged, moved behind {@link NativeProcess}.
 */
public class WindowsProcess implements NativeProcess {

	private static final int PROCESS_VM_READ = 0x0010;
	private static final int PROCESS_VM_OPERATION = 0x0008;

	private final Kernel32 kernel32 =
			Native.load("kernel32", Kernel32.class, W32APIOptions.UNICODE_OPTIONS);

	private int pid = 0;
	private String name = "";
	private Pointer process = null;

	@Override
	public int findPid(String nameContains) {
		this.name = nameContains;
		Tlhelp32.PROCESSENTRY32.ByReference processEntry = new Tlhelp32.PROCESSENTRY32.ByReference();
		WinNT.HANDLE snapshot = kernel32.CreateToolhelp32Snapshot(Tlhelp32.TH32CS_SNAPPROCESS, new WinDef.DWORD(0));
		try {
			while (kernel32.Process32Next(snapshot, processEntry)) {
				if (Native.toString(processEntry.szExeFile).contains(nameContains)) {
					pid = processEntry.th32ProcessID.intValue();
					return pid;
				}
			}
		} finally {
			kernel32.CloseHandle(snapshot);
		}
		pid = 0;
		return 0;
	}

	@Override
	public boolean open(int pid) {
		this.pid = pid;
		process = kernel32.OpenProcess(PROCESS_VM_READ | PROCESS_VM_OPERATION, true, pid);
		return process != null;
	}

	@Override
	public long findSignature(byte[] key, int keyPos) {
		long a = findBytes(key, null);
		return a == 0 ? 0 : a - keyPos;
	}

	@Override
	public long findBytes(byte[] pattern, byte[] mask) {
		Tlhelp32.MODULEENTRY32W module = getModule(pid, name);
		if (module == null) {
			return 0;
		}
		long base = Pointer.nativeValue(module.modBaseAddr);
		int size = module.modBaseSize.intValue();
		Memory mem = read(base, size);
		if (mem == null) {
			return 0;
		}
		ByteBuffer buffer = mem.getByteBuffer(0, size);
		for (int i = 0; i + pattern.length <= size; i++) {
			boolean found = true;
			for (int j = 0; j < pattern.length; j++) {
				int m = mask == null ? 0xff : (mask[j] & 0xff);
				if ((buffer.get(i + j) & m) != (pattern[j] & m)) {
					found = false;
					break;
				}
			}
			if (found) {
				return base + i;
			}
		}
		return 0;
	}

	@Override
	public Memory read(long address, int length) {
		if (process == null) {
			return null;
		}
		Memory out = new Memory(length);
		kernel32.ReadProcessMemory(process, address, out, length, new IntByReference(0));
		return out;
	}

	@Override
	public void write(long address, byte[] data) {
		if (process == null) {
			return;
		}
		Memory toWrite = new Memory(data.length);
		for (int i = 0; i < data.length; i++) {
			toWrite.setByte(i, data[i]);
		}
		kernel32.WriteProcessMemory(process, address, toWrite, data.length, null);
	}

	private Tlhelp32.MODULEENTRY32W getModule(int pid, String name) {
		Tlhelp32.MODULEENTRY32W moduleEntry = new Tlhelp32.MODULEENTRY32W.ByReference();
		WinNT.HANDLE snapshot = kernel32.CreateToolhelp32Snapshot(Tlhelp32.TH32CS_SNAPMODULE, new WinDef.DWORD(pid));
		Tlhelp32.MODULEENTRY32W match = null;
		if (kernel32.Module32FirstW(snapshot, moduleEntry)) {
			do {
				if (new String(moduleEntry.szModule).contains(name)) {
					match = moduleEntry;
					break;
				}
			} while (kernel32.Module32NextW(snapshot, moduleEntry));
		}
		kernel32.CloseHandle(snapshot);
		return match;
	}
}
