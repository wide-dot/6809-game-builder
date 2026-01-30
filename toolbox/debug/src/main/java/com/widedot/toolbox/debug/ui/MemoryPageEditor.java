package com.widedot.toolbox.debug.ui;

import java.nio.ByteBuffer;

import org.lwjgl.system.MemoryUtil;

import com.widedot.toolbox.debug.Emulator;
import com.widedot.toolbox.debug.OS;

import imgui.internal.ImGui;
import imgui.type.ImBoolean;

public class MemoryPageEditor {

	private static final int PAGE_SIZE = 0x4000;
	private static final int BASE_ADDRESS = 0x10000;
	
	private imgui.extension.memedit.MemoryEditor mem_edit;
	private int pageNumber;
	private ByteBuffer hexBuffer;

	public MemoryPageEditor(int pageNumber) {
		this.pageNumber = pageNumber;
		this.mem_edit = new imgui.extension.memedit.MemoryEditor();
	}

	public void show(ImBoolean showImGui) {
		if (ImGui.begin("Memory Page " + pageNumber, showImGui)) {
			int pageAddress = BASE_ADDRESS + ((pageNumber - 4) * PAGE_SIZE);
	       	hexBuffer = OS.readMemory(Emulator.process, Emulator.ramAddress + pageAddress, PAGE_SIZE).getByteBuffer(0, PAGE_SIZE);
	       	mem_edit.drawWindow("Memory Page " + pageNumber,  MemoryUtil.memAddress(hexBuffer), hexBuffer.capacity(), pageAddress);
	       	System.gc();
   		    ImGui.end();
		}
	}
}
