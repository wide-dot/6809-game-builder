package com.widedot.toolbox.graphics.compiled;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map.Entry;

import com.widedot.m6809.gamebuilder.util.asm.AsmSourceCode;
import com.widedot.m6809.gamebuilder.util.graphics.Image;
import com.widedot.m6809.gamebuilder.util.graphics.Sprite;
import com.widedot.m6809.gamebuilder.util.graphics.SubSprite;
import com.widedot.toolbox.graphics.compiled.Encoder;

public class ImageSet {
	
	public HashMap<String,HashMap<String,Image>> images; // a map of images grouped by type and by name 
	
	public ImageSet() {
		images = new HashMap<String,HashMap<String,Image>>();
	}
	
	public void addImage(Image img) {
		HashMap<String,Image> typesImg = images.get(img.name);
		if (typesImg == null) {
			typesImg = new HashMap<String,Image>();
			images.put(img.name, typesImg);
		}
		typesImg.put(img.type, img);		
	}
	
	public void registerImage(Image img, Encoder e) {
		// cell size is expected to be 64 in asm engine, value 12 is the number of bytes used by IRQ to save all registers
		// in all irq routines, stack is moved to a dedicated buffer in irq, thus no need to go higher than 12
		img.nb_cell = (e.getEraseDataSize() + 12 + 64 - 1) / 64;						
		addImage(img);
	}
	
	public void generate(String fileName) {
//		
//		AsmSourceCode asm;
//		
//		// index to image sub set is limited to an offset of +127
//		// this version go up to +102 so it's fine
//		
//		List<String> line = new ArrayList<String>();
//		int imageSet_header = 7, imageSubSet_header = 6;
//		int x_size = 0;
//		int y_size = 0;
//		int center_offset = 0;
//		int n_offset = 0;
//		int n_x1 = 0;
//		int n_y1 = 0;
//		int x_offset = 0;
//		int x_x1 = 0;
//		int x_y1 = 0;		
//		int y_offset = 0;
//		int y_x1 = 0;
//		int y_y1 = 0;		
//		int xy_offset = 0;
//		int xy_x1 = 0;
//		int xy_y1 = 0;		
//		int nb0_offset = 0;
//		int nd0_offset = 0;
//		int nb1_offset = 0;
//		int nd1_offset = 0;
//		int xb0_offset = 0;
//		int xd0_offset = 0;
//		int xb1_offset = 0;
//		int xd1_offset = 0;
//		int yb0_offset = 0;
//		int yd0_offset = 0;
//		int yb1_offset = 0;
//		int yd1_offset = 0;
//		int xyb0_offset = 0;
//		int xyd0_offset = 0;
//		int xyb1_offset = 0;
//		int xyd1_offset = 0;		
//		
//		if (asm != null) {
//			if (sprite.associatedIdx != null) {
//				asm.addConstant("Id"+sprite.name, sprite.associatedIdx);
//				asm.addFcb(new String[]{sprite.associatedIdx});
//			}
//			asm.addLabel(sprite.name+" ");
//		}
//		
//		if (sprite.subSprites.containsKey("NB0") || sprite.subSprites.containsKey("ND0") || sprite.subSprites.containsKey("NB1") || sprite.subSprites.containsKey("ND1")) {
//			n_offset = imageSet_header;			
//		}
//
//		if (sprite.subSprites.containsKey("NB0")) {
//			nb0_offset = imageSubSet_header;
//			n_x1 = sprite.subSprites.get("NB0").x1_offset;
//			n_y1 = sprite.subSprites.get("NB0").y1_offset;
//		}
//		
//		if (sprite.subSprites.containsKey("ND0")) {
//			nd0_offset = (nb0_offset>0?7:0) + imageSubSet_header;
//			n_x1 = sprite.subSprites.get("ND0").x1_offset;	
//			n_y1 = sprite.subSprites.get("ND0").y1_offset;
//		}
//
//		if (sprite.subSprites.containsKey("NB1")) {
//			nb1_offset = (nd0_offset>0?3:0) + (nb0_offset>0?7:0) + imageSubSet_header;
//			n_x1 = sprite.subSprites.get("NB1").x1_offset;
//			n_y1 = sprite.subSprites.get("NB1").y1_offset;
//		}
//		
//		if (sprite.subSprites.containsKey("ND1")) {
//			nd1_offset = (nb1_offset>0?7:0) + (nd0_offset>0?3:0) + (nb0_offset>0?7:0) + imageSubSet_header;
//			n_x1 = sprite.subSprites.get("ND1").x1_offset;
//			n_y1 = sprite.subSprites.get("ND1").y1_offset;
//		}		
//		
//		if (sprite.subSprites.containsKey("XB0") || sprite.subSprites.containsKey("XD0") || sprite.subSprites.containsKey("XB1") || sprite.subSprites.containsKey("XD1")) {
//			x_offset = (nd1_offset>0?3:0) + (nb1_offset>0?7:0) + (nd0_offset>0?3:0) + (nb0_offset>0?7:0) + (n_offset>0?n_offset+imageSubSet_header:imageSet_header);			
//		}		
//		
//		if (sprite.subSprites.containsKey("XB0")) {
//			xb0_offset = imageSubSet_header;
//			x_x1 = sprite.subSprites.get("XB0").x1_offset;
//			x_y1 = sprite.subSprites.get("XB0").y1_offset;
//		}
//		
//		if (sprite.subSprites.containsKey("XD0")) {
//			xd0_offset = (xb0_offset>0?7:0) + imageSubSet_header;
//			x_x1 = sprite.subSprites.get("XD0").x1_offset;
//			x_y1 = sprite.subSprites.get("XD0").y1_offset;			
//		}
//
//		if (sprite.subSprites.containsKey("XB1")) {
//			xb1_offset = (xd0_offset>0?3:0) + (xb0_offset>0?7:0) + imageSubSet_header;
//			x_x1 = sprite.subSprites.get("XB1").x1_offset;
//			x_y1 = sprite.subSprites.get("XB1").y1_offset;			
//		}
//		
//		if (sprite.subSprites.containsKey("XD1")) {
//			xd1_offset = (xb1_offset>0?7:0) + (xd0_offset>0?3:0) + (xb0_offset>0?7:0) + imageSubSet_header;
//			x_x1 = sprite.subSprites.get("XD1").x1_offset;
//			x_y1 = sprite.subSprites.get("XD1").y1_offset;			
//		}		
//		
//		if (sprite.subSprites.containsKey("YB0") || sprite.subSprites.containsKey("YD0") || sprite.subSprites.containsKey("YB1") || sprite.subSprites.containsKey("YD1")) {
//			y_offset = (xd1_offset>0?3:0) + (xb1_offset>0?7:0) + (xd0_offset>0?3:0) + (xb0_offset>0?7:0) + (x_offset>0?x_offset+imageSubSet_header:imageSet_header);			
//		}		
//		
//		if (sprite.subSprites.containsKey("YB0")) {
//			yb0_offset = imageSubSet_header;
//			y_x1 = sprite.subSprites.get("YB0").x1_offset;
//			y_y1 = sprite.subSprites.get("YB0").y1_offset;
//		}
//		
//		if (sprite.subSprites.containsKey("YD0")) {
//			yd0_offset = (yb0_offset>0?7:0) + imageSubSet_header;
//			y_x1 = sprite.subSprites.get("YD0").x1_offset;
//			y_y1 = sprite.subSprites.get("YD0").y1_offset;			
//		}
//
//		if (sprite.subSprites.containsKey("YB1")) {
//			yb1_offset = (yd0_offset>0?3:0) + (yb0_offset>0?7:0) + imageSubSet_header;
//			y_x1 = sprite.subSprites.get("YB1").x1_offset;
//			y_y1 = sprite.subSprites.get("YB1").y1_offset;			
//		}
//		
//		if (sprite.subSprites.containsKey("YD1")) {
//			yd1_offset = (yb1_offset>0?7:0) + (yd0_offset>0?3:0) + (yb0_offset>0?7:0) + imageSubSet_header;
//			y_x1 = sprite.subSprites.get("YD1").x1_offset;
//			y_y1 = sprite.subSprites.get("YD1").y1_offset;
//		}
//		
//		if (sprite.subSprites.containsKey("XYB0") || sprite.subSprites.containsKey("XYD0") || sprite.subSprites.containsKey("XYB1") || sprite.subSprites.containsKey("XYD1")) {
//			xy_offset = (yd1_offset>0?3:0) + (yb1_offset>0?7:0) + (yd0_offset>0?3:0) + (yb0_offset>0?7:0) + (y_offset>0?y_offset+imageSubSet_header:imageSet_header);			
//		}		
//		
//		if (sprite.subSprites.containsKey("XYB0")) {
//			xyb0_offset = imageSubSet_header;
//			xy_x1 = sprite.subSprites.get("XYB0").x1_offset;
//			xy_y1 = sprite.subSprites.get("XYB0").y1_offset;
//		}
//		
//		if (sprite.subSprites.containsKey("XYD0")) {
//			xyd0_offset = (xyb0_offset>0?7:0) + imageSubSet_header;
//			xy_x1 = sprite.subSprites.get("XYD0").x1_offset;
//			xy_y1 = sprite.subSprites.get("XYD0").y1_offset;			
//		}
//
//		if (sprite.subSprites.containsKey("XYB1")) {
//			xyb1_offset = (xyd0_offset>0?3:0) + (xyb0_offset>0?7:0) + imageSubSet_header;
//			xy_x1 = sprite.subSprites.get("XYB1").x1_offset;
//			xy_y1 = sprite.subSprites.get("XYB1").y1_offset;
//		}
//		
//		if (sprite.subSprites.containsKey("XYD1")) {
//			xyd1_offset = (xyb1_offset>0?7:0) + (xyd0_offset>0?3:0) + (xyb0_offset>0?7:0) + imageSubSet_header;
//			xy_x1 = sprite.subSprites.get("XYD1").x1_offset;
//			xy_y1 = sprite.subSprites.get("XYD1").y1_offset;
//		}		
//		
//		for (Entry<String, SubSprite> subSprite : sprite.subSprites.entrySet()) {
//			x_size = subSprite.getValue().x_size;
//			y_size = subSprite.getValue().y_size;
//			center_offset = subSprite.getValue().center_offset;
//			break;
//		}
//		
//		// assigne les images symétriques vides afin d'empêcher les crashs au runtime
//		int def_value = 0;
//		
//		// search a value by priority
//		if (xy_offset > 0)
//			def_value = xy_offset;
//		if (y_offset > 0)
//			def_value = y_offset;		
//		if (x_offset > 0)
//			def_value = x_offset;		
//		if (n_offset > 0)
//			def_value = n_offset;
//		
//		// assign to empty offset
//		if (xy_offset == 0)
//			xy_offset = def_value;
//		if (y_offset == 0)
//			y_offset = def_value;		
//		if (x_offset == 0)
//			x_offset = def_value;		
//		if (n_offset == 0)
//			n_offset = def_value;		
//		
//		line.add(String.format("$%1$02X", n_offset)); // unsigned value
//		line.add(String.format("$%1$02X", x_offset)); // unsigned value
//		line.add(String.format("$%1$02X", y_offset)); // unsigned value
//		line.add(String.format("$%1$02X", xy_offset)); // unsigned value		
//		line.add(String.format("$%1$02X", x_size)); // unsigned value
//		line.add(String.format("$%1$02X", y_size)); // unsigned value
//		line.add(String.format("$%1$02X", center_offset)); // unsigned value
//		
//		if (nb0_offset+nd0_offset+nb1_offset+nd1_offset>0) {
//			line.add(String.format("$%1$02X", nb0_offset)); // unsigned value
//			line.add(String.format("$%1$02X", nd0_offset)); // unsigned value
//			line.add(String.format("$%1$02X", nb1_offset)); // unsigned value
//			line.add(String.format("$%1$02X", nd1_offset)); // unsigned value
//			line.add(String.format("$%1$02X", n_x1 & 0xFF)); // signed value		
//			line.add(String.format("$%1$02X", n_y1 & 0xFF)); // signed value			
//			if (sprite.subSprites.containsKey("NB0")) {
//				getImgSubSpriteIndex(gm, sprite.subSprites.get("NB0"), line, mode);
//			}
//
//			if (sprite.subSprites.containsKey("ND0")) {
//				getImgSubSpriteIndex(gm, sprite.subSprites.get("ND0"), line, mode);
//			}
//
//			if (sprite.subSprites.containsKey("NB1")) {
//				getImgSubSpriteIndex(gm, sprite.subSprites.get("NB1"), line, mode);
//			}
//
//			if (sprite.subSprites.containsKey("ND1")) {
//				getImgSubSpriteIndex(gm, sprite.subSprites.get("ND1"), line, mode);
//			}
//		}
//		
//		if (xb0_offset+xd0_offset+xb1_offset+xd1_offset>0) {
//			line.add(String.format("$%1$02X", xb0_offset)); // unsigned value
//			line.add(String.format("$%1$02X", xd0_offset)); // unsigned value
//			line.add(String.format("$%1$02X", xb1_offset)); // unsigned value
//			line.add(String.format("$%1$02X", xd1_offset)); // unsigned value
//			line.add(String.format("$%1$02X", x_x1 & 0xFF)); // signed value		
//			line.add(String.format("$%1$02X", x_y1 & 0xFF)); // signed value			
//			if (sprite.subSprites.containsKey("XB0")) {
//				getImgSubSpriteIndex(gm, sprite.subSprites.get("XB0"), line, mode);
//			}
//
//			if (sprite.subSprites.containsKey("XD0")) {
//				getImgSubSpriteIndex(gm, sprite.subSprites.get("XD0"), line, mode);
//			}
//
//			if (sprite.subSprites.containsKey("XB1")) {
//				getImgSubSpriteIndex(gm, sprite.subSprites.get("XB1"), line, mode);
//			}
//
//			if (sprite.subSprites.containsKey("XD1")) {
//				getImgSubSpriteIndex(gm, sprite.subSprites.get("XD1"), line, mode);
//			}
//		}
//		
//		if (yb0_offset+yd0_offset+yb1_offset+yd1_offset>0) {
//			line.add(String.format("$%1$02X", yb0_offset)); // unsigned value
//			line.add(String.format("$%1$02X", yd0_offset)); // unsigned value
//			line.add(String.format("$%1$02X", yb1_offset)); // unsigned value
//			line.add(String.format("$%1$02X", yd1_offset)); // unsigned value
//			line.add(String.format("$%1$02X", y_x1 & 0xFF)); // signed value		
//			line.add(String.format("$%1$02X", y_y1 & 0xFF)); // signed value			
//			if (sprite.subSprites.containsKey("YB0")) {
//				getImgSubSpriteIndex(gm, sprite.subSprites.get("YB0"), line, mode);
//			}
//
//			if (sprite.subSprites.containsKey("YD0")) {
//				getImgSubSpriteIndex(gm, sprite.subSprites.get("YD0"), line, mode);
//			}
//
//			if (sprite.subSprites.containsKey("YB1")) {
//				getImgSubSpriteIndex(gm, sprite.subSprites.get("YB1"), line, mode);
//			}
//
//			if (sprite.subSprites.containsKey("YD1")) {
//				getImgSubSpriteIndex(gm, sprite.subSprites.get("YD1"), line, mode);
//			}
//		}
//		
//		if (xyb0_offset+xyd0_offset+xyb1_offset+xyd1_offset>0) {
//			line.add(String.format("$%1$02X", xyb0_offset)); // unsigned value
//			line.add(String.format("$%1$02X", xyd0_offset)); // unsigned value
//			line.add(String.format("$%1$02X", xyb1_offset)); // unsigned value
//			line.add(String.format("$%1$02X", xyd1_offset)); // unsigned value
//			line.add(String.format("$%1$02X", xy_x1 & 0xFF)); // signed value		
//			line.add(String.format("$%1$02X", xy_y1 & 0xFF)); // signed value			
//			if (sprite.subSprites.containsKey("XYB0")) {
//				getImgSubSpriteIndex(gm, sprite.subSprites.get("XYB0"), line, mode);
//			}
//
//			if (sprite.subSprites.containsKey("XYD0")) {
//				getImgSubSpriteIndex(gm, sprite.subSprites.get("XYD0"), line, mode);
//			}
//
//			if (sprite.subSprites.containsKey("XYB1")) {
//				getImgSubSpriteIndex(gm, sprite.subSprites.get("XYB1"), line, mode);
//			}
//
//			if (sprite.subSprites.containsKey("XYD1")) {
//				getImgSubSpriteIndex(gm, sprite.subSprites.get("XYD1"), line, mode);
//			}
//		}		
//		
//		String[] result = line.toArray(new String[0]);
//		if (asm != null) {
//			asm.addFcb(result);
//			asm.flush();
//		}
//		return line.size()+(sprite.associatedIdx != null?1:0);
//	}
//	
//	private static void getImgSubSpriteIndex(SubSprite s, List<String> line, int mode) {
//		
//		line.add("pge_"+s.name);
//		line.add("adr_"+s.name);
//	
//		if (s.erase != null) {
//			line.add("pge_"+s.name);
//			line.add("adr_"+s.name);
//			line.add(String.format("$%1$02X", s.nb_cell)); // unsigned value
//		}
	}
}
