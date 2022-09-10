package com.widedot.m6809.gamebuilder.image;

import java.util.ArrayList;
import java.util.List;

public class Tileset {

	public String name = "";
	public String fileName;
	public int nbTiles;
	public int nbColumns;
	public int nbRows;
	public int centerMode;
	public boolean inRAM = false;

	public List<TileBin> tiles;

	public Tileset(String name) {
		this.name = name;
		this.tiles = new ArrayList<TileBin>();
	}
}