package com.widedot.m6809.gamebuilder.util.graphics;

public class SubSprite {

	public Sprite parent;
	public String name = "";

	public int x_size;
	public int y_size;	
	public int x1_offset;	
	public int y1_offset;
	public int nb_cell;
	public int center_offset;
	
	public SubSprite(Sprite p) {
		parent = p;
	}

	public void setName(String name) {
		this.name = name;
	}
}