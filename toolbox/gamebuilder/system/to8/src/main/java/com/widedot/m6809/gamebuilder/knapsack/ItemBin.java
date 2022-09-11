package com.widedot.m6809.gamebuilder.knapsack;

import java.util.HashMap;

import com.widedot.m6809.gamebuilder.builder.GameMode;
import com.widedot.m6809.gamebuilder.builder.Object;
import com.widedot.m6809.gamebuilder.storage.DataIndex;
import com.widedot.m6809.gamebuilder.storage.RAMLoaderIndex;

public abstract class ItemBin {
	
	public byte[] bin;
	public 	HashMap<GameMode, DataIndex> dataIndex =  new HashMap<GameMode, DataIndex>();
	public int uncompressedSize = 0;
	
	// MEGAROM T.2
	public int t2_page;	          // page de source ROM
	public int t2_address;	      // adresse RAM	
	public int t2_endAddress;     // adresse de source (ptr de fin pour exomizer) ROM

	abstract public String getFullName();
	abstract public Object getObject();
	abstract public RAMLoaderIndex getRAMLoaderIndex();
}