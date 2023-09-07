package com.widedot.toolbox.debug;
import com.sun.jna.Native;

import com.sun.jna.platform.win32.Psapi;
import com.sun.jna.platform.win32.WinDef.HMODULE;
import com.sun.jna.platform.win32.WinNT.HANDLE;
import com.sun.jna.ptr.IntByReference;
import com.sun.jna.win32.W32APIOptions;

public interface CustomPsapi extends Psapi{

    Psapi INSTANCE = Native.load("psapi", Psapi.class, W32APIOptions.DEFAULT_OPTIONS);

    public void EnumProcessModulesEx(HANDLE hProcess, HMODULE[] lphModule, int cb, 
    IntByReference lpcbNeeded, int dwFilterFlag);


}