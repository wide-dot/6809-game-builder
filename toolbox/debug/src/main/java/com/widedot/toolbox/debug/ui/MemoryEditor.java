package com.widedot.toolbox.debug.ui;

import java.nio.ByteBuffer;

import org.lwjgl.system.MemoryUtil;

import com.widedot.toolbox.debug.Emulator;
import com.widedot.toolbox.debug.OS;

import imgui.internal.ImGui;
import imgui.type.ImBoolean;

public class MemoryEditor {

	private static imgui.extension.memedit.MemoryEditor mem_edit = new imgui.extension.memedit.MemoryEditor();
	private static ByteBuffer hexBuffer;

	public static void show(ImBoolean showImGui) {

		if (ImGui.begin("Memory Editor", showImGui)) {
	       	hexBuffer = OS.readMemory(Emulator.process,Emulator.ramAddress,0x80000).getByteBuffer(0, 0x80000);
	       	mem_edit.drawWindow("Memory Editor",  MemoryUtil.memAddress(hexBuffer), hexBuffer.capacity());
	       	System.gc();
   		    ImGui.end();
		}
	}
}
