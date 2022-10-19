package com.widedot.toolbox.graphics.compiler.imageset;

import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map.Entry;

import com.widedot.m6809.gamebuilder.util.asm.AsmSourceCode;
import com.widedot.toolbox.graphics.compiler.Image;
import com.widedot.toolbox.graphics.compiler.encoder.bdraw.AssemblyGenerator;
import com.widedot.toolbox.graphics.compiler.transformer.mirror.Mirror;
import com.widedot.toolbox.graphics.compiler.transformer.shift.Shift;

public class ImageSet {
	
	private AsmSourceCode asm;
	private HashMap<String,HashMap<String,Image>> images; // a map of images grouped by type and name 
	
	public ImageSet(Integer type) {
		// type is unimplemented for now
		images = new HashMap<String,HashMap<String,Image>>();
	}
	
	public void addImage(Image img) {
		HashMap<String,Image> imgTypes = images.get(img.getName());
		if (imgTypes == null) {
			imgTypes = new HashMap<String,Image>();
			images.put(img.getName(), imgTypes);
		}
		imgTypes.put(img.getVariant(), img);		
	}
	
	public void generate(String fileName) throws Exception {
		
		// index to image sub set is limited to an offset of +127
		// this version go up to +102 so it's fine
		
		asm = new AsmSourceCode(Paths.get(fileName));
		List<String> line = new ArrayList<String>();
		
		for (Entry<String, HashMap<String, Image>> imgEntry : images.entrySet()) {
		
			HashMap<String, Image> imgTypes = imgEntry.getValue();
				
			int imageSet_header = 7, imageSubSet_header = 6;
			int x_size = 0;
			int y_size = 0;
			int center_offset = 0;
			int n_offset = 0;
			int n_x1 = 0;
			int n_y1 = 0;
			int x_offset = 0;
			int x_x1 = 0;
			int x_y1 = 0;		
			int y_offset = 0;
			int y_x1 = 0;
			int y_y1 = 0;		
			int xy_offset = 0;
			int xy_x1 = 0;
			int xy_y1 = 0;		
			int nb0_offset = 0;
			int nd0_offset = 0;
			int nb1_offset = 0;
			int nd1_offset = 0;
			int xb0_offset = 0;
			int xd0_offset = 0;
			int xb1_offset = 0;
			int xd1_offset = 0;
			int yb0_offset = 0;
			int yd0_offset = 0;
			int yb1_offset = 0;
			int yd1_offset = 0;
			int xyb0_offset = 0;
			int xyd0_offset = 0;
			int xyb1_offset = 0;
			int xyd1_offset = 0;		
			
			Image img = ((Image)imgTypes.values().toArray()[0]);
			Integer index = img.index;
			if (index != null) {
				asm.addConstant("idx_"+imgEntry.getKey(), index.toString());
				asm.addFcb(new String[]{index.toString()});
			}
			x_size = img.x_size;
			y_size = img.y_size;
			center_offset = img.getCenterOffset();
			
			asm.addLabel("set_"+imgEntry.getKey());

			if (imgTypes.containsKey(Image.TYPE_BDRAW+"_"+Mirror.NONE+"_"+Shift.SHIFT_0) ||
				imgTypes.containsKey(Image.TYPE_DRAW+"_"+Mirror.NONE+"_"+Shift.SHIFT_0) ||
				imgTypes.containsKey(Image.TYPE_BDRAW+"_"+Mirror.NONE+"_"+Shift.SHIFT_1) ||
				imgTypes.containsKey(Image.TYPE_DRAW+"_"+Mirror.NONE+"_"+Shift.SHIFT_1)) {
				n_offset = imageSet_header;			
			}
	
			if (imgTypes.containsKey(Image.TYPE_BDRAW+"_"+Mirror.NONE+"_"+Shift.SHIFT_0)) {
				nb0_offset = imageSubSet_header;
				n_x1 = imgTypes.get(Image.TYPE_BDRAW+"_"+Mirror.NONE+"_"+Shift.SHIFT_0).x1_offset;
				n_y1 = imgTypes.get(Image.TYPE_BDRAW+"_"+Mirror.NONE+"_"+Shift.SHIFT_0).y1_offset;
			}
			
			if (imgTypes.containsKey(Image.TYPE_DRAW+"_"+Mirror.NONE+"_"+Shift.SHIFT_0)) {
				nd0_offset = (nb0_offset>0?7:0) + imageSubSet_header;
				n_x1 = imgTypes.get(Image.TYPE_DRAW+"_"+Mirror.NONE+"_"+Shift.SHIFT_0).x1_offset;	
				n_y1 = imgTypes.get(Image.TYPE_DRAW+"_"+Mirror.NONE+"_"+Shift.SHIFT_0).y1_offset;
			}
	
			if (imgTypes.containsKey(Image.TYPE_BDRAW+"_"+Mirror.NONE+"_"+Shift.SHIFT_1)) {
				nb1_offset = (nd0_offset>0?3:0) + (nb0_offset>0?7:0) + imageSubSet_header;
				n_x1 = imgTypes.get(Image.TYPE_BDRAW+"_"+Mirror.NONE+"_"+Shift.SHIFT_1).x1_offset;
				n_y1 = imgTypes.get(Image.TYPE_BDRAW+"_"+Mirror.NONE+"_"+Shift.SHIFT_1).y1_offset;
			}
			
			if (imgTypes.containsKey(Image.TYPE_DRAW+"_"+Mirror.NONE+"_"+Shift.SHIFT_1)) {
				nd1_offset = (nb1_offset>0?7:0) + (nd0_offset>0?3:0) + (nb0_offset>0?7:0) + imageSubSet_header;
				n_x1 = imgTypes.get(Image.TYPE_DRAW+"_"+Mirror.NONE+"_"+Shift.SHIFT_1).x1_offset;
				n_y1 = imgTypes.get(Image.TYPE_DRAW+"_"+Mirror.NONE+"_"+Shift.SHIFT_1).y1_offset;
			}		
			
			if (imgTypes.containsKey(Image.TYPE_BDRAW+"_"+Mirror.X+"_"+Shift.SHIFT_0) ||
				imgTypes.containsKey(Image.TYPE_DRAW+"_"+Mirror.X+"_"+Shift.SHIFT_0) ||
				imgTypes.containsKey(Image.TYPE_BDRAW+"_"+Mirror.X+"_"+Shift.SHIFT_1) ||
				imgTypes.containsKey(Image.TYPE_DRAW+"_"+Mirror.X+"_"+Shift.SHIFT_1)) {
				x_offset = (nd1_offset>0?3:0) + (nb1_offset>0?7:0) + (nd0_offset>0?3:0) + (nb0_offset>0?7:0) + (n_offset>0?n_offset+imageSubSet_header:imageSet_header);			
			}		
			
			if (imgTypes.containsKey(Image.TYPE_BDRAW+"_"+Mirror.X+"_"+Shift.SHIFT_0)) {
				xb0_offset = imageSubSet_header;
				x_x1 = imgTypes.get(Image.TYPE_BDRAW+"_"+Mirror.X+"_"+Shift.SHIFT_0).x1_offset;
				x_y1 = imgTypes.get(Image.TYPE_BDRAW+"_"+Mirror.X+"_"+Shift.SHIFT_0).y1_offset;
			}
			
			if (imgTypes.containsKey(Image.TYPE_DRAW+"_"+Mirror.X+"_"+Shift.SHIFT_0)) {
				xd0_offset = (xb0_offset>0?7:0) + imageSubSet_header;
				x_x1 = imgTypes.get(Image.TYPE_DRAW+"_"+Mirror.X+"_"+Shift.SHIFT_0).x1_offset;
				x_y1 = imgTypes.get(Image.TYPE_DRAW+"_"+Mirror.X+"_"+Shift.SHIFT_0).y1_offset;			
			}
	
			if (imgTypes.containsKey(Image.TYPE_BDRAW+"_"+Mirror.X+"_"+Shift.SHIFT_1)) {
				xb1_offset = (xd0_offset>0?3:0) + (xb0_offset>0?7:0) + imageSubSet_header;
				x_x1 = imgTypes.get(Image.TYPE_BDRAW+"_"+Mirror.X+"_"+Shift.SHIFT_1).x1_offset;
				x_y1 = imgTypes.get(Image.TYPE_BDRAW+"_"+Mirror.X+"_"+Shift.SHIFT_1).y1_offset;			
			}
			
			if (imgTypes.containsKey(Image.TYPE_DRAW+"_"+Mirror.X+"_"+Shift.SHIFT_1)) {
				xd1_offset = (xb1_offset>0?7:0) + (xd0_offset>0?3:0) + (xb0_offset>0?7:0) + imageSubSet_header;
				x_x1 = imgTypes.get(Image.TYPE_DRAW+"_"+Mirror.X+"_"+Shift.SHIFT_1).x1_offset;
				x_y1 = imgTypes.get(Image.TYPE_DRAW+"_"+Mirror.X+"_"+Shift.SHIFT_1).y1_offset;			
			}		
			
			if (imgTypes.containsKey(Image.TYPE_BDRAW+"_"+Mirror.Y+"_"+Shift.SHIFT_0) ||
				imgTypes.containsKey(Image.TYPE_DRAW+"_"+Mirror.Y+"_"+Shift.SHIFT_0) ||
				imgTypes.containsKey(Image.TYPE_BDRAW+"_"+Mirror.Y+"_"+Shift.SHIFT_1) ||
				imgTypes.containsKey(Image.TYPE_DRAW+"_"+Mirror.Y+"_"+Shift.SHIFT_1)) {
				y_offset = (xd1_offset>0?3:0) + (xb1_offset>0?7:0) + (xd0_offset>0?3:0) + (xb0_offset>0?7:0) + (x_offset>0?x_offset+imageSubSet_header:imageSet_header);			
			}		
			
			if (imgTypes.containsKey(Image.TYPE_BDRAW+"_"+Mirror.Y+"_"+Shift.SHIFT_0)) {
				yb0_offset = imageSubSet_header;
				y_x1 = imgTypes.get(Image.TYPE_BDRAW+"_"+Mirror.Y+"_"+Shift.SHIFT_0).x1_offset;
				y_y1 = imgTypes.get(Image.TYPE_BDRAW+"_"+Mirror.Y+"_"+Shift.SHIFT_0).y1_offset;
			}
			
			if (imgTypes.containsKey(Image.TYPE_DRAW+"_"+Mirror.Y+"_"+Shift.SHIFT_0)) {
				yd0_offset = (yb0_offset>0?7:0) + imageSubSet_header;
				y_x1 = imgTypes.get(Image.TYPE_DRAW+"_"+Mirror.Y+"_"+Shift.SHIFT_0).x1_offset;
				y_y1 = imgTypes.get(Image.TYPE_DRAW+"_"+Mirror.Y+"_"+Shift.SHIFT_0).y1_offset;			
			}
	
			if (imgTypes.containsKey(Image.TYPE_BDRAW+"_"+Mirror.Y+"_"+Shift.SHIFT_1)) {
				yb1_offset = (yd0_offset>0?3:0) + (yb0_offset>0?7:0) + imageSubSet_header;
				y_x1 = imgTypes.get(Image.TYPE_BDRAW+"_"+Mirror.Y+"_"+Shift.SHIFT_1).x1_offset;
				y_y1 = imgTypes.get(Image.TYPE_BDRAW+"_"+Mirror.Y+"_"+Shift.SHIFT_1).y1_offset;			
			}
			
			if (imgTypes.containsKey(Image.TYPE_DRAW+"_"+Mirror.Y+"_"+Shift.SHIFT_1)) {
				yd1_offset = (yb1_offset>0?7:0) + (yd0_offset>0?3:0) + (yb0_offset>0?7:0) + imageSubSet_header;
				y_x1 = imgTypes.get(Image.TYPE_DRAW+"_"+Mirror.Y+"_"+Shift.SHIFT_1).x1_offset;
				y_y1 = imgTypes.get(Image.TYPE_DRAW+"_"+Mirror.Y+"_"+Shift.SHIFT_1).y1_offset;
			}
			
			if (imgTypes.containsKey(Image.TYPE_BDRAW+"_"+Mirror.XY+"_"+Shift.SHIFT_0) ||
				imgTypes.containsKey(Image.TYPE_DRAW+"_"+Mirror.XY+"_"+Shift.SHIFT_0) ||
				imgTypes.containsKey(Image.TYPE_BDRAW+"_"+Mirror.XY+"_"+Shift.SHIFT_1) ||
				imgTypes.containsKey(Image.TYPE_DRAW+"_"+Mirror.XY+"_"+Shift.SHIFT_1)) {
				xy_offset = (yd1_offset>0?3:0) + (yb1_offset>0?7:0) + (yd0_offset>0?3:0) + (yb0_offset>0?7:0) + (y_offset>0?y_offset+imageSubSet_header:imageSet_header);			
			}		
			
			if (imgTypes.containsKey(Image.TYPE_BDRAW+"_"+Mirror.XY+"_"+Shift.SHIFT_0)) {
				xyb0_offset = imageSubSet_header;
				xy_x1 = imgTypes.get(Image.TYPE_BDRAW+"_"+Mirror.XY+"_"+Shift.SHIFT_0).x1_offset;
				xy_y1 = imgTypes.get(Image.TYPE_BDRAW+"_"+Mirror.XY+"_"+Shift.SHIFT_0).y1_offset;
			}
			
			if (imgTypes.containsKey(Image.TYPE_DRAW+"_"+Mirror.XY+"_"+Shift.SHIFT_0)) {
				xyd0_offset = (xyb0_offset>0?7:0) + imageSubSet_header;
				xy_x1 = imgTypes.get(Image.TYPE_DRAW+"_"+Mirror.XY+"_"+Shift.SHIFT_0).x1_offset;
				xy_y1 = imgTypes.get(Image.TYPE_DRAW+"_"+Mirror.XY+"_"+Shift.SHIFT_0).y1_offset;			
			}
	
			if (imgTypes.containsKey(Image.TYPE_BDRAW+"_"+Mirror.XY+"_"+Shift.SHIFT_1)) {
				xyb1_offset = (xyd0_offset>0?3:0) + (xyb0_offset>0?7:0) + imageSubSet_header;
				xy_x1 = imgTypes.get(Image.TYPE_BDRAW+"_"+Mirror.XY+"_"+Shift.SHIFT_1).x1_offset;
				xy_y1 = imgTypes.get(Image.TYPE_BDRAW+"_"+Mirror.XY+"_"+Shift.SHIFT_1).y1_offset;
			}
			
			if (imgTypes.containsKey(Image.TYPE_DRAW+"_"+Mirror.XY+"_"+Shift.SHIFT_1)) {
				xyd1_offset = (xyb1_offset>0?7:0) + (xyd0_offset>0?3:0) + (xyb0_offset>0?7:0) + imageSubSet_header;
				xy_x1 = imgTypes.get(Image.TYPE_DRAW+"_"+Mirror.XY+"_"+Shift.SHIFT_1).x1_offset;
				xy_y1 = imgTypes.get(Image.TYPE_DRAW+"_"+Mirror.XY+"_"+Shift.SHIFT_1).y1_offset;
			}		
			
			// default empty images
			int def_value = 0;
			
			// search a value by priority
			if (xy_offset > 0)
				def_value = xy_offset;
			if (y_offset > 0)
				def_value = y_offset;		
			if (x_offset > 0)
				def_value = x_offset;		
			if (n_offset > 0)
				def_value = n_offset;
			
			// assign to empty offset
			if (xy_offset == 0)
				xy_offset = def_value;
			if (y_offset == 0)
				y_offset = def_value;		
			if (x_offset == 0)
				x_offset = def_value;		
			if (n_offset == 0)
				n_offset = def_value;		
			
			// write index
			line.add(String.format("$%1$02X", n_offset)); // unsigned value
			line.add(String.format("$%1$02X", x_offset)); // unsigned value
			line.add(String.format("$%1$02X", y_offset)); // unsigned value
			line.add(String.format("$%1$02X", xy_offset)); // unsigned value		
			line.add(String.format("$%1$02X", x_size)); // unsigned value
			line.add(String.format("$%1$02X", y_size)); // unsigned value
			line.add(String.format("$%1$02X", center_offset)); // unsigned value
			flush(line);
			
			if (nb0_offset+nd0_offset+nb1_offset+nd1_offset>0) {
				line.add(String.format("$%1$02X", nb0_offset)); // unsigned value
				line.add(String.format("$%1$02X", nd0_offset)); // unsigned value
				line.add(String.format("$%1$02X", nb1_offset)); // unsigned value
				line.add(String.format("$%1$02X", nd1_offset)); // unsigned value
				line.add(String.format("$%1$02X", n_x1 & 0xFF)); // signed value		
				line.add(String.format("$%1$02X", n_y1 & 0xFF)); // signed value
				flush(line);
				
				img = imgTypes.get(Image.TYPE_BDRAW+"_"+Mirror.NONE+"_"+Shift.SHIFT_0);
				addImgSymbol(img, line);
	
				img = imgTypes.get(Image.TYPE_DRAW+"_"+Mirror.NONE+"_"+Shift.SHIFT_0);
				addImgSymbol(img, line);
	
				img = imgTypes.get(Image.TYPE_BDRAW+"_"+Mirror.NONE+"_"+Shift.SHIFT_1);
				addImgSymbol(img, line);
	
				img = imgTypes.get(Image.TYPE_DRAW+"_"+Mirror.NONE+"_"+Shift.SHIFT_1);
				addImgSymbol(img, line);
				flush(line);
			}
			
			if (xb0_offset+xd0_offset+xb1_offset+xd1_offset>0) {
				line.add(String.format("$%1$02X", xb0_offset)); // unsigned value
				line.add(String.format("$%1$02X", xd0_offset)); // unsigned value
				line.add(String.format("$%1$02X", xb1_offset)); // unsigned value
				line.add(String.format("$%1$02X", xd1_offset)); // unsigned value
				line.add(String.format("$%1$02X", x_x1 & 0xFF)); // signed value		
				line.add(String.format("$%1$02X", x_y1 & 0xFF)); // signed value	
				flush(line);
				
				img = imgTypes.get(Image.TYPE_BDRAW+"_"+Mirror.X+"_"+Shift.SHIFT_0);
				addImgSymbol(img, line);
	
				img = imgTypes.get(Image.TYPE_DRAW+"_"+Mirror.X+"_"+Shift.SHIFT_0);
				addImgSymbol(img, line);
	
				img = imgTypes.get(Image.TYPE_BDRAW+"_"+Mirror.X+"_"+Shift.SHIFT_1);
				addImgSymbol(img, line);
	
				img = imgTypes.get(Image.TYPE_DRAW+"_"+Mirror.X+"_"+Shift.SHIFT_1);
				addImgSymbol(img, line);
				flush(line);
				
			}
			
			if (yb0_offset+yd0_offset+yb1_offset+yd1_offset>0) {
				line.add(String.format("$%1$02X", yb0_offset)); // unsigned value
				line.add(String.format("$%1$02X", yd0_offset)); // unsigned value
				line.add(String.format("$%1$02X", yb1_offset)); // unsigned value
				line.add(String.format("$%1$02X", yd1_offset)); // unsigned value
				line.add(String.format("$%1$02X", y_x1 & 0xFF)); // signed value		
				line.add(String.format("$%1$02X", y_y1 & 0xFF)); // signed value	
				flush(line);
				
				img = imgTypes.get(Image.TYPE_BDRAW+"_"+Mirror.Y+"_"+Shift.SHIFT_0);
				addImgSymbol(img, line);
	
				img = imgTypes.get(Image.TYPE_DRAW+"_"+Mirror.Y+"_"+Shift.SHIFT_0);
				addImgSymbol(img, line);
	
				img = imgTypes.get(Image.TYPE_BDRAW+"_"+Mirror.Y+"_"+Shift.SHIFT_1);
				addImgSymbol(img, line);
	
				img = imgTypes.get(Image.TYPE_DRAW+"_"+Mirror.Y+"_"+Shift.SHIFT_1);
				addImgSymbol(img, line);	
				flush(line);
				
			}
			
			if (xyb0_offset+xyd0_offset+xyb1_offset+xyd1_offset>0) {
				line.add(String.format("$%1$02X", xyb0_offset)); // unsigned value
				line.add(String.format("$%1$02X", xyd0_offset)); // unsigned value
				line.add(String.format("$%1$02X", xyb1_offset)); // unsigned value
				line.add(String.format("$%1$02X", xyd1_offset)); // unsigned value
				line.add(String.format("$%1$02X", xy_x1 & 0xFF)); // signed value		
				line.add(String.format("$%1$02X", xy_y1 & 0xFF)); // signed value			
				flush(line);
				
				img = imgTypes.get(Image.TYPE_BDRAW+"_"+Mirror.XY+"_"+Shift.SHIFT_0);
				addImgSymbol(img, line);
	
				img = imgTypes.get(Image.TYPE_DRAW+"_"+Mirror.XY+"_"+Shift.SHIFT_0);
				addImgSymbol(img, line);
	
				img = imgTypes.get(Image.TYPE_BDRAW+"_"+Mirror.XY+"_"+Shift.SHIFT_1);
				addImgSymbol(img, line);
	
				img = imgTypes.get(Image.TYPE_DRAW+"_"+Mirror.XY+"_"+Shift.SHIFT_1);
				addImgSymbol(img, line);
				flush(line);
				
			}		
		}

		flush(line);
		return;
	}
	
	private void addImgSymbol(Image img, List<String> line) {
		if (img != null) {
			line.add("pge_"+img.getFullName());
			line.add("adr_"+img.getFullName());
		
			if (img.nb_cell != null) {
				line.add("pge_"+img.getFullName()+AssemblyGenerator.ERASE_SUFFIXE);
				line.add("adr_"+img.getFullName()+AssemblyGenerator.ERASE_SUFFIXE);
				line.add(String.format("$%1$02X", img.nb_cell)); // unsigned value
			}
		}
	}
	
	private void flush(List<String> line) {
		String[] result = line.toArray(new String[0]);
		if (asm != null) {
			asm.addFcb(result);
			asm.flush();
		}
		line.clear();
	}
}
