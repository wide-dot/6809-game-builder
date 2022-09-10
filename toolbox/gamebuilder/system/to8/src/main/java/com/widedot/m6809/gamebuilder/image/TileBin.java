package com.widedot.m6809.gamebuilder.image;

import com.widedot.m6809.gamebuilder.builder.Object;
import com.widedot.m6809.gamebuilder.storage.RAMLoaderIndex;
import com.widedot.m6809.gamebuilder.util.knapsack.ItemBin;

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