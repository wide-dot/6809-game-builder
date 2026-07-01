package com.widedot.toolbox.debug.os;

import com.sun.jna.Library;
import com.sun.jna.Native;
import com.sun.jna.Pointer;
import com.sun.jna.ptr.IntByReference;
import com.sun.jna.ptr.LongByReference;

/**
 * Minimal JNA binding to the macOS system library (libSystem) for the Mach VM
 * and libproc calls used by {@link MacProcess}.
 * <p>
 * The mach_vm_* variants take explicit 64-bit addresses/sizes ({@code long}),
 * while mach_port_t / kern_return_t are 32-bit ({@code int}).
 */
public interface SystemB extends Library {

	SystemB INSTANCE = Native.load("System", SystemB.class);

	int PROC_ALL_PIDS = 1;
	int VM_REGION_BASIC_INFO_64 = 9;
	int VM_REGION_BASIC_INFO_COUNT_64 = 10;

	// task_for_pid(mach_port_t target_tport, int pid, mach_port_t *t)
	int task_for_pid(int targetTask, int pid, IntByReference out);

	// mach_vm_read_overwrite(vm_task, address, size, data /*dest*/, *outsize)
	int mach_vm_read_overwrite(int task, long address, long size, long data, LongByReference outSize);

	// mach_vm_write(vm_task, address, data, count)
	int mach_vm_write(int task, long address, Pointer data, int count);

	// mach_vm_region(task, *address, *size, flavor, info, *infoCnt, *objectName)
	int mach_vm_region(int task, LongByReference address, LongByReference size,
			int flavor, Pointer info, IntByReference infoCnt, IntByReference objectName);

	// libproc (bundled in libSystem)
	int proc_listpids(int type, int typeinfo, Pointer buffer, int buffersize);

	int proc_pidpath(int pid, Pointer buffer, int buffersize);
}
