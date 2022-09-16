package com.widedot.m6809.gamebuilder.to8.image;

import com.widedot.m6809.gamebuilder.to8.builder.FileNames;
import com.widedot.m6809.gamebuilder.to8.builder.Object;
import com.widedot.m6809.gamebuilder.to8.knapsack.ItemBin;
import com.widedot.m6809.gamebuilder.to8.storage.RAMLoaderIndex;

public class AnimationBin extends ItemBin{

	public String name = "";
	public String fileName;

	public AnimationBin(String objName) {
		this.fileName = objName + FileNames.ANIMATION;
	}
	
	public void setName(String name) {
		this.name = name;
	}	
	
	public String getFullName() {
		return "AnimationBin "+this.name;
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