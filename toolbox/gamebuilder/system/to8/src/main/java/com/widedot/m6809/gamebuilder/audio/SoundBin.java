package com.widedot.m6809.gamebuilder.audio;

import com.widedot.m6809.gamebuilder.builder.Object;
import com.widedot.m6809.gamebuilder.storage.RAMLoaderIndex;
import com.widedot.m6809.gamebuilder.util.knapsack.ItemBin;

public class SoundBin extends ItemBin{

	public String name = "";
	public boolean inRAM = false;
	
	public SoundBin() {	
	}
	
	public void setName(String name) {
		this.name = name;
	}	
	
	public String getFullName() {
		return "ObjectBin "+this.name;
	}

	public Object getObject() {
		return null;
	}

	public RAMLoaderIndex getRAMLoaderIndex() {
		return null;
	}
	
}