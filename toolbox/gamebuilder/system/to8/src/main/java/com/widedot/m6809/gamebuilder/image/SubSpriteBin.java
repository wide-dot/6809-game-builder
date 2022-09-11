package com.widedot.m6809.gamebuilder.image;

import com.widedot.m6809.gamebuilder.builder.Object;
import com.widedot.m6809.gamebuilder.storage.RAMLoaderIndex;
import com.widedot.m6809.gamebuilder.knapsack.ItemBin;

public class SubSpriteBin extends ItemBin{

	public SubSprite parent;
	public String name = "";
	public boolean inRAM = false;

	public SubSpriteBin(SubSprite p) {
		parent = p;
	}
	
	public void setName(String name) {
		this.name = name;
	}
	
	public String getFullName() {
		return "SpriteBin "+this.parent.parent.name + " " + this.parent.name + " " + this.name;
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