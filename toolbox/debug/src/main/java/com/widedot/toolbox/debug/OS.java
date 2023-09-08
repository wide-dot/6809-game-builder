package com.widedot.toolbox.debug;

import com.sun.jna.Memory;
import com.sun.jna.Native;
import com.sun.jna.Pointer;
import com.sun.jna.platform.win32.Tlhelp32;
import com.sun.jna.platform.win32.WinDef;
import com.sun.jna.platform.win32.WinNT;
import com.sun.jna.ptr.IntByReference;
import com.sun.jna.win32.W32APIOptions;

public class OS {
	
    static Kernel32 kernel32 = (Kernel32) Native.load("kernel32",Kernel32.class, W32APIOptions.UNICODE_OPTIONS);
    static User32 user32 = (User32) Native.load("user32", User32.class, W32APIOptions.UNICODE_OPTIONS);

    public static int PROCESS_VM_READ= 0x0010;
    public static int PROCESS_VM_WRITE = 0x0020;
    public static int PROCESS_VM_OPERATION = 0x0008;	
	
    public static int getProcessId(String name) {	 
    	Tlhelp32.PROCESSENTRY32.ByReference processEntry = new Tlhelp32.PROCESSENTRY32.ByReference();          
    	WinNT.HANDLE snapshot = kernel32.CreateToolhelp32Snapshot(Tlhelp32.TH32CS_SNAPPROCESS, new WinDef.DWORD(0));
    	try  {
    		while (kernel32.Process32Next(snapshot, processEntry)) {             
    			if (Native.toString(processEntry.szExeFile).contains(name)) {
    				return processEntry.th32ProcessID.intValue();
    			}
    		}
    	}
    	finally {
    		kernel32.CloseHandle(snapshot);
    	}
    	return 0;
   }
    
    public static Tlhelp32.MODULEENTRY32W getModule(int pid, String name) {
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
    
   public static Pointer openProcess(int permissions, int pid) {
        Pointer process = kernel32.OpenProcess(permissions, true, pid);
        return process;
   }

   public static long findDynAddress(Pointer process, int[] offsets, long baseAddress)
   {

       long pointer = baseAddress;

       int size = 4;
       Memory pTemp = new Memory(size);
       long pointerAddress = 0;

       for(int i = 0; i < offsets.length; i++)
       {
           if(i == 0)
           {
                kernel32.ReadProcessMemory(process, pointer, pTemp, size, null);
           }

           pointerAddress = ((pTemp.getInt(0)+offsets[i]));

           if(i != offsets.length-1)
                kernel32.ReadProcessMemory(process, pointerAddress, pTemp, size, null);


       }

       return pointerAddress;
   }

   public static Memory readMemory(Pointer process, long address, int bytesToRead) {
       IntByReference read = new IntByReference(0);
       Memory output = new Memory(bytesToRead);

       kernel32.ReadProcessMemory(process, address, output, bytesToRead, read);
       return output;
   }

   public static void writeMemory(Pointer process, long address, byte[] data)
   {
       int size = data.length;
       Memory toWrite = new Memory(size);

       for(int i = 0; i < size; i++)
       {
    	   toWrite.setByte(i, data[i]);
       }

       kernel32.WriteProcessMemory(process, address, toWrite, size, null);
   }
}
