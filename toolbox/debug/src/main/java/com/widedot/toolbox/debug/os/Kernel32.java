package com.widedot.toolbox.debug.os;

import com.sun.jna.Pointer;
import com.sun.jna.platform.win32.Tlhelp32.MODULEENTRY32W;
import com.sun.jna.platform.win32.Tlhelp32.PROCESSENTRY32.ByReference;
import com.sun.jna.platform.win32.WinDef.DWORD;
import com.sun.jna.platform.win32.WinNT.HANDLE;
import com.sun.jna.ptr.IntByReference;
import com.sun.jna.win32.StdCallLibrary;

public interface Kernel32 extends StdCallLibrary {

	boolean WriteProcessMemory(Pointer p, long address, Pointer buffer, int size, IntByReference written);

	boolean ReadProcessMemory(Pointer hProcess, long inBaseAddress, Pointer outputBuffer, int nSize, IntByReference outNumberOfBytesRead);

	Pointer OpenProcess(int desired, boolean inherit, int pid);

	int GetLastError();

	HANDLE CreateToolhelp32Snapshot(DWORD th32csSnapprocess, DWORD dword);

	boolean Process32Next(HANDLE snapshot, ByReference processEntry);

	void CloseHandle(HANDLE snapshot);

	boolean Module32FirstW(HANDLE snapshot, MODULEENTRY32W moduleEntry);

	boolean Module32NextW(HANDLE snapshot, MODULEENTRY32W moduleEntry);
}
