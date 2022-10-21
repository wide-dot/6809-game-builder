package com.widedot.m6809.oldgamebuilder.to8.image;

import com.widedot.m6809.oldgamebuilder.to8.builder.Object;
import com.widedot.m6809.oldgamebuilder.to8.knapsack.ItemBin;
import com.widedot.m6809.oldgamebuilder.to8.storage.RAMLoaderIndex;

public class TileBin extends ItemBin{

	public Tileset parent;
	public String name = "";
	public boolean inRAM = false;
	public byte[] pixels0;
	public byte[] pixels1;

	public TileBin(Tileset p) {
		parent = p;
	}
	
	public void setName(String name) {
		this.name = name;
	}
	
	public String getFullName() {
		return "TileBin " + this.parent.name + " " + this.name;
	}

	@Override
	public Object getObject() {
		// TODO Auto-generated method stub
		return null;
	}

	@Override
	public RAMLoaderIndex getRAMLoaderIndex() {
		// TODO Auto-generated method stub
		return null;
	}
}