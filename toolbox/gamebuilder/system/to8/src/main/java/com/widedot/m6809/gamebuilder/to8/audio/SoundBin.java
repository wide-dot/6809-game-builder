package com.widedot.m6809.gamebuilder.to8.audio;

import com.widedot.m6809.gamebuilder.to8.builder.Object;
import com.widedot.m6809.gamebuilder.to8.knapsack.ItemBin;
import com.widedot.m6809.gamebuilder.to8.storage.RAMLoaderIndex;

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