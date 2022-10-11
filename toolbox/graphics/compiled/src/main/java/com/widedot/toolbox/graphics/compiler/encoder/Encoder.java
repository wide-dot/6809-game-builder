package com.widedot.toolbox.graphics.compiler.encoder;

public abstract class Encoder {

	public abstract void generateCode();
	
	public abstract int getEraseDataSize();

	public abstract int getX1_offset();

	public abstract int getY1_offset();

	public abstract int getX_size();

	public abstract int getY_size();

}
