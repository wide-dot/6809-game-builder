package com.widedot.m6809.oldgamebuilder.to8.builder;

import com.widedot.m6809.oldgamebuilder.to8.builder.Object;
import com.widedot.m6809.oldgamebuilder.to8.knapsack.ItemBin;
import com.widedot.m6809.oldgamebuilder.to8.storage.RAMLoaderIndex;

public class ObjectBin extends ItemBin{

	public String name = "";
	public Object parent;
	
	public ObjectBin() {
	}
	
	public ObjectBin(Object obj) {
		this.parent = obj;
	}	
	
	public void setName(String name) {
		this.name = name;
	}	
	
	public String getFullName() {
		return "ObjectBin "+this.name;
	}

	public Object getObject() {
		return parent;
	}

	public RAMLoaderIndex getRAMLoaderIndex() {
		return null;
	}
			
}