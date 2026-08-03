package com.widedot.toolbox.graphics.gfxcomp.imageset;

import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map.Entry;

import com.widedot.m6809.util.asm.AsmSourceCode;
import com.widedot.toolbox.graphics.gfxcomp.Image;
import com.widedot.toolbox.graphics.gfxcomp.encoder.bdraw.AssemblyGenerator;
import com.widedot.toolbox.graphics.gfxcomp.transformer.mirror.Mirror;
import com.widedot.toolbox.graphics.gfxcomp.transformer.shift.Shift;

public class ImageSet implements com.widedot.m6809.gamebuilder.spi.globals.ImageSets.Index {

	private AsmSourceCode asm;
	private HashMap<String,HashMap<String,Image>> images; // a map of images grouped by type and name

	/** name of the direntry the images end up in, or null outside a build */
	private String file;

	/**
	 * Asked for the page of each image when the set is spread over several
	 * direntries, null when one {@code <file>$PAGE} says it for the whole set.
	 */
	private com.widedot.m6809.gamebuilder.spi.globals.ImageSets.PageOf pages;

	public ImageSet(Integer type) {
		this(type, null);
	}

	public ImageSet(Integer type, String file) {
		// type is unimplemented for now
		this.file = file;
		images = new HashMap<String,HashMap<String,Image>>();
	}

	/**
	 * Writes the index of a set whose code lives elsewhere — one or several
	 * other direntries, typically the members of a pageset.
	 *
	 * Two things change against the in-unit form. The page is asked per image
	 * rather than referenced once through {@code <file>$PAGE} : two frames of
	 * one animation legitimately sit on different pages, and the runtime reads
	 * the page from the frame it is drawing. And the drawing routines are
	 * declared EXTERNAL here, since this unit no longer contains them — in a
	 * {@code .static} section the builder bakes them against the placement it
	 * already knows, exactly as it does for a tilemap indexing a tileset.
	 */
	@Override
	public void generate(String path, String section,
			com.widedot.m6809.gamebuilder.spi.globals.ImageSets.PageOf pages) throws Exception {

		this.pages = pages;
		asm = new AsmSourceCode(Paths.get(path));
		asm.addCommentLine("the drawing code lives in other files of this build : the builder"
				+ " resolves each reference against where that file is loaded");
		for (Entry<String, HashMap<String, Image>> imgEntry : images.entrySet()) {
			for (Image img : imgEntry.getValue().values()) {
				asm.add("adr_" + img.getFullName() + " EXTERNAL");
				if (img.nb_cell != null) {
					asm.add("adr_" + img.getFullName() + AssemblyGenerator.ERASE_SUFFIXE
							+ " EXTERNAL");
				}
			}
		}
		asm.flush();
		body(section);
	}
	
	public void addImage(Image img) throws Exception {
		HashMap<String,Image> imgTypes = images.get(img.getName());
		if (imgTypes == null) {
			imgTypes = new HashMap<String,Image>();
			images.put(img.getName(), imgTypes);
		}
		// draw, rle and zx0 share the D slot, so two of them on one image would
		// silently drop whichever was declared first
		Image previous = imgTypes.put(img.getVariant(), img);
		if (previous != null) {
			throw new Exception("image " + img.getName() + " has two encoders on variant "
			                    + img.getVariant() + " : only one can be indexed");
		}
	}
	
	public void generate(String fileName) throws Exception {

		asm = new AsmSourceCode(Paths.get(fileName));

		// The page an image ends up in is only known once it is loaded, so the
		// index references it through a relocation the load time linker fills
		// in (externPg) : an 8 bit external named <direntry>$PAGE, resolved to
		// the page holding that file. v1 had no such step — its builder placed
		// the pages itself and patched the value in. Every image of an imageset
		// compiled into this unit is in the same file, hence one symbol.
		if (file != null) {
			asm.addCommentLine("page of the file holding this code, resolved at load time");
			asm.add(file + "$PAGE EXTERNAL");
		}
		body(null);
	}

	private void body(String section) throws Exception {

		// index to image sub set is limited to an offset of +127
		// this version go up to +102 so it's fine

		List<String> line = new ArrayList<String>();

		// what the rest of the game links against : an index per image, and the
		// drawing routines themselves for code that calls one directly. When
		// the code is elsewhere they are imports, declared by generate() above.
		asm.addCommentLine("imageset interface");
		for (Entry<String, HashMap<String, Image>> imgEntry : images.entrySet()) {
			asm.add("set_" + imgEntry.getKey() + " EXPORT");
			if (((Image) imgEntry.getValue().values().toArray()[0]).index != null) {
				asm.add("idx_" + imgEntry.getKey() + " EXPORT");
			}
			if (pages != null) {
				continue;
			}
			for (Image img : imgEntry.getValue().values()) {
				asm.add("adr_" + img.getFullName() + " EXPORT");
				if (img.nb_cell != null) {
					asm.add("adr_" + img.getFullName() + AssemblyGenerator.ERASE_SUFFIXE + " EXPORT");
				}
			}
		}
		if (section != null) {
			asm.add(" SECTION " + section);
		}
		asm.flush();

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
			int cml_offset = 0;			
			
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

			cml_offset += imageSet_header;
			
			if (imgTypes.containsKey(Image.variantKey(Image.TYPE_BDRAW, Mirror.NONE, Shift.SHIFT_0)) ||
				imgTypes.containsKey(Image.variantKey(Image.TYPE_DRAW, Mirror.NONE, Shift.SHIFT_0)) ||
				imgTypes.containsKey(Image.variantKey(Image.TYPE_BDRAW, Mirror.NONE, Shift.SHIFT_1)) ||
				imgTypes.containsKey(Image.variantKey(Image.TYPE_DRAW, Mirror.NONE, Shift.SHIFT_1))) {
				n_offset = cml_offset;
			}
	
			if (imgTypes.containsKey(Image.variantKey(Image.TYPE_BDRAW, Mirror.NONE, Shift.SHIFT_0))) {
				nb0_offset = imageSubSet_header;
				n_x1 = imgTypes.get(Image.variantKey(Image.TYPE_BDRAW, Mirror.NONE, Shift.SHIFT_0)).x1_offset;
				n_y1 = imgTypes.get(Image.variantKey(Image.TYPE_BDRAW, Mirror.NONE, Shift.SHIFT_0)).y1_offset;
			}
			
			if (imgTypes.containsKey(Image.variantKey(Image.TYPE_DRAW, Mirror.NONE, Shift.SHIFT_0))) {
				nd0_offset = (nb0_offset>0?7:0) + imageSubSet_header;
				n_x1 = imgTypes.get(Image.variantKey(Image.TYPE_DRAW, Mirror.NONE, Shift.SHIFT_0)).x1_offset;	
				n_y1 = imgTypes.get(Image.variantKey(Image.TYPE_DRAW, Mirror.NONE, Shift.SHIFT_0)).y1_offset;
			}
	
			if (imgTypes.containsKey(Image.variantKey(Image.TYPE_BDRAW, Mirror.NONE, Shift.SHIFT_1))) {
				nb1_offset = (nd0_offset>0?3:0) + (nb0_offset>0?7:0) + imageSubSet_header;
				n_x1 = imgTypes.get(Image.variantKey(Image.TYPE_BDRAW, Mirror.NONE, Shift.SHIFT_1)).x1_offset;
				n_y1 = imgTypes.get(Image.variantKey(Image.TYPE_BDRAW, Mirror.NONE, Shift.SHIFT_1)).y1_offset;
			}
			
			if (imgTypes.containsKey(Image.variantKey(Image.TYPE_DRAW, Mirror.NONE, Shift.SHIFT_1))) {
				nd1_offset = (nb1_offset>0?7:0) + (nd0_offset>0?3:0) + (nb0_offset>0?7:0) + imageSubSet_header;
				n_x1 = imgTypes.get(Image.variantKey(Image.TYPE_DRAW, Mirror.NONE, Shift.SHIFT_1)).x1_offset;
				n_y1 = imgTypes.get(Image.variantKey(Image.TYPE_DRAW, Mirror.NONE, Shift.SHIFT_1)).y1_offset;
			}		
			
			cml_offset += (nd1_offset>0?3:0) + (nb1_offset>0?7:0) + (nd0_offset>0?3:0) + (nb0_offset>0?7:0) + (n_offset>0?imageSubSet_header:0);
			
			if (imgTypes.containsKey(Image.variantKey(Image.TYPE_BDRAW, Mirror.X, Shift.SHIFT_0)) ||
				imgTypes.containsKey(Image.variantKey(Image.TYPE_DRAW, Mirror.X, Shift.SHIFT_0)) ||
				imgTypes.containsKey(Image.variantKey(Image.TYPE_BDRAW, Mirror.X, Shift.SHIFT_1)) ||
				imgTypes.containsKey(Image.variantKey(Image.TYPE_DRAW, Mirror.X, Shift.SHIFT_1))) {
				x_offset = cml_offset;			
			}		
			
			if (imgTypes.containsKey(Image.variantKey(Image.TYPE_BDRAW, Mirror.X, Shift.SHIFT_0))) {
				xb0_offset = imageSubSet_header;
				x_x1 = imgTypes.get(Image.variantKey(Image.TYPE_BDRAW, Mirror.X, Shift.SHIFT_0)).x1_offset;
				x_y1 = imgTypes.get(Image.variantKey(Image.TYPE_BDRAW, Mirror.X, Shift.SHIFT_0)).y1_offset;
			}
			
			if (imgTypes.containsKey(Image.variantKey(Image.TYPE_DRAW, Mirror.X, Shift.SHIFT_0))) {
				xd0_offset = (xb0_offset>0?7:0) + imageSubSet_header;
				x_x1 = imgTypes.get(Image.variantKey(Image.TYPE_DRAW, Mirror.X, Shift.SHIFT_0)).x1_offset;
				x_y1 = imgTypes.get(Image.variantKey(Image.TYPE_DRAW, Mirror.X, Shift.SHIFT_0)).y1_offset;			
			}
	
			if (imgTypes.containsKey(Image.variantKey(Image.TYPE_BDRAW, Mirror.X, Shift.SHIFT_1))) {
				xb1_offset = (xd0_offset>0?3:0) + (xb0_offset>0?7:0) + imageSubSet_header;
				x_x1 = imgTypes.get(Image.variantKey(Image.TYPE_BDRAW, Mirror.X, Shift.SHIFT_1)).x1_offset;
				x_y1 = imgTypes.get(Image.variantKey(Image.TYPE_BDRAW, Mirror.X, Shift.SHIFT_1)).y1_offset;			
			}
			
			if (imgTypes.containsKey(Image.variantKey(Image.TYPE_DRAW, Mirror.X, Shift.SHIFT_1))) {
				xd1_offset = (xb1_offset>0?7:0) + (xd0_offset>0?3:0) + (xb0_offset>0?7:0) + imageSubSet_header;
				x_x1 = imgTypes.get(Image.variantKey(Image.TYPE_DRAW, Mirror.X, Shift.SHIFT_1)).x1_offset;
				x_y1 = imgTypes.get(Image.variantKey(Image.TYPE_DRAW, Mirror.X, Shift.SHIFT_1)).y1_offset;			
			}		
			
			cml_offset += (xd1_offset>0?3:0) + (xb1_offset>0?7:0) + (xd0_offset>0?3:0) + (xb0_offset>0?7:0) + (x_offset>0?imageSubSet_header:0);
			
			if (imgTypes.containsKey(Image.variantKey(Image.TYPE_BDRAW, Mirror.Y, Shift.SHIFT_0)) ||
				imgTypes.containsKey(Image.variantKey(Image.TYPE_DRAW, Mirror.Y, Shift.SHIFT_0)) ||
				imgTypes.containsKey(Image.variantKey(Image.TYPE_BDRAW, Mirror.Y, Shift.SHIFT_1)) ||
				imgTypes.containsKey(Image.variantKey(Image.TYPE_DRAW, Mirror.Y, Shift.SHIFT_1))) {
				y_offset = cml_offset;			
			}		
			
			if (imgTypes.containsKey(Image.variantKey(Image.TYPE_BDRAW, Mirror.Y, Shift.SHIFT_0))) {
				yb0_offset = imageSubSet_header;
				y_x1 = imgTypes.get(Image.variantKey(Image.TYPE_BDRAW, Mirror.Y, Shift.SHIFT_0)).x1_offset;
				y_y1 = imgTypes.get(Image.variantKey(Image.TYPE_BDRAW, Mirror.Y, Shift.SHIFT_0)).y1_offset;
			}
			
			if (imgTypes.containsKey(Image.variantKey(Image.TYPE_DRAW, Mirror.Y, Shift.SHIFT_0))) {
				yd0_offset = (yb0_offset>0?7:0) + imageSubSet_header;
				y_x1 = imgTypes.get(Image.variantKey(Image.TYPE_DRAW, Mirror.Y, Shift.SHIFT_0)).x1_offset;
				y_y1 = imgTypes.get(Image.variantKey(Image.TYPE_DRAW, Mirror.Y, Shift.SHIFT_0)).y1_offset;			
			}
	
			if (imgTypes.containsKey(Image.variantKey(Image.TYPE_BDRAW, Mirror.Y, Shift.SHIFT_1))) {
				yb1_offset = (yd0_offset>0?3:0) + (yb0_offset>0?7:0) + imageSubSet_header;
				y_x1 = imgTypes.get(Image.variantKey(Image.TYPE_BDRAW, Mirror.Y, Shift.SHIFT_1)).x1_offset;
				y_y1 = imgTypes.get(Image.variantKey(Image.TYPE_BDRAW, Mirror.Y, Shift.SHIFT_1)).y1_offset;			
			}
			
			if (imgTypes.containsKey(Image.variantKey(Image.TYPE_DRAW, Mirror.Y, Shift.SHIFT_1))) {
				yd1_offset = (yb1_offset>0?7:0) + (yd0_offset>0?3:0) + (yb0_offset>0?7:0) + imageSubSet_header;
				y_x1 = imgTypes.get(Image.variantKey(Image.TYPE_DRAW, Mirror.Y, Shift.SHIFT_1)).x1_offset;
				y_y1 = imgTypes.get(Image.variantKey(Image.TYPE_DRAW, Mirror.Y, Shift.SHIFT_1)).y1_offset;
			}
			
			cml_offset += (yd1_offset>0?3:0) + (yb1_offset>0?7:0) + (yd0_offset>0?3:0) + (yb0_offset>0?7:0) + (y_offset>0?imageSubSet_header:0);
			
			if (imgTypes.containsKey(Image.variantKey(Image.TYPE_BDRAW, Mirror.XY, Shift.SHIFT_0)) ||
				imgTypes.containsKey(Image.variantKey(Image.TYPE_DRAW, Mirror.XY, Shift.SHIFT_0)) ||
				imgTypes.containsKey(Image.variantKey(Image.TYPE_BDRAW, Mirror.XY, Shift.SHIFT_1)) ||
				imgTypes.containsKey(Image.variantKey(Image.TYPE_DRAW, Mirror.XY, Shift.SHIFT_1))) {
				xy_offset = cml_offset;			
			}		
			
			if (imgTypes.containsKey(Image.variantKey(Image.TYPE_BDRAW, Mirror.XY, Shift.SHIFT_0))) {
				xyb0_offset = imageSubSet_header;
				xy_x1 = imgTypes.get(Image.variantKey(Image.TYPE_BDRAW, Mirror.XY, Shift.SHIFT_0)).x1_offset;
				xy_y1 = imgTypes.get(Image.variantKey(Image.TYPE_BDRAW, Mirror.XY, Shift.SHIFT_0)).y1_offset;
			}
			
			if (imgTypes.containsKey(Image.variantKey(Image.TYPE_DRAW, Mirror.XY, Shift.SHIFT_0))) {
				xyd0_offset = (xyb0_offset>0?7:0) + imageSubSet_header;
				xy_x1 = imgTypes.get(Image.variantKey(Image.TYPE_DRAW, Mirror.XY, Shift.SHIFT_0)).x1_offset;
				xy_y1 = imgTypes.get(Image.variantKey(Image.TYPE_DRAW, Mirror.XY, Shift.SHIFT_0)).y1_offset;			
			}
	
			if (imgTypes.containsKey(Image.variantKey(Image.TYPE_BDRAW, Mirror.XY, Shift.SHIFT_1))) {
				xyb1_offset = (xyd0_offset>0?3:0) + (xyb0_offset>0?7:0) + imageSubSet_header;
				xy_x1 = imgTypes.get(Image.variantKey(Image.TYPE_BDRAW, Mirror.XY, Shift.SHIFT_1)).x1_offset;
				xy_y1 = imgTypes.get(Image.variantKey(Image.TYPE_BDRAW, Mirror.XY, Shift.SHIFT_1)).y1_offset;
			}
			
			if (imgTypes.containsKey(Image.variantKey(Image.TYPE_DRAW, Mirror.XY, Shift.SHIFT_1))) {
				xyd1_offset = (xyb1_offset>0?7:0) + (xyd0_offset>0?3:0) + (xyb0_offset>0?7:0) + imageSubSet_header;
				xy_x1 = imgTypes.get(Image.variantKey(Image.TYPE_DRAW, Mirror.XY, Shift.SHIFT_1)).x1_offset;
				xy_y1 = imgTypes.get(Image.variantKey(Image.TYPE_DRAW, Mirror.XY, Shift.SHIFT_1)).y1_offset;
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
			line.add(String.format("$%1$02X", center_offset & 0xFF)); // signed value // unsigned value
			flush(line);
			
			if (nb0_offset+nd0_offset+nb1_offset+nd1_offset>0) {
				line.add(String.format("$%1$02X", nb0_offset)); // unsigned value
				line.add(String.format("$%1$02X", nd0_offset)); // unsigned value
				line.add(String.format("$%1$02X", nb1_offset)); // unsigned value
				line.add(String.format("$%1$02X", nd1_offset)); // unsigned value
				line.add(String.format("$%1$02X", n_x1 & 0xFF)); // signed value		
				line.add(String.format("$%1$02X", n_y1 & 0xFF)); // signed value
				flush(line);
				
				img = imgTypes.get(Image.variantKey(Image.TYPE_BDRAW, Mirror.NONE, Shift.SHIFT_0));
				addImgSymbol(img, line);
	
				img = imgTypes.get(Image.variantKey(Image.TYPE_DRAW, Mirror.NONE, Shift.SHIFT_0));
				addImgSymbol(img, line);
	
				img = imgTypes.get(Image.variantKey(Image.TYPE_BDRAW, Mirror.NONE, Shift.SHIFT_1));
				addImgSymbol(img, line);
	
				img = imgTypes.get(Image.variantKey(Image.TYPE_DRAW, Mirror.NONE, Shift.SHIFT_1));
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
				
				img = imgTypes.get(Image.variantKey(Image.TYPE_BDRAW, Mirror.X, Shift.SHIFT_0));
				addImgSymbol(img, line);
	
				img = imgTypes.get(Image.variantKey(Image.TYPE_DRAW, Mirror.X, Shift.SHIFT_0));
				addImgSymbol(img, line);
	
				img = imgTypes.get(Image.variantKey(Image.TYPE_BDRAW, Mirror.X, Shift.SHIFT_1));
				addImgSymbol(img, line);
	
				img = imgTypes.get(Image.variantKey(Image.TYPE_DRAW, Mirror.X, Shift.SHIFT_1));
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
				
				img = imgTypes.get(Image.variantKey(Image.TYPE_BDRAW, Mirror.Y, Shift.SHIFT_0));
				addImgSymbol(img, line);
	
				img = imgTypes.get(Image.variantKey(Image.TYPE_DRAW, Mirror.Y, Shift.SHIFT_0));
				addImgSymbol(img, line);
	
				img = imgTypes.get(Image.variantKey(Image.TYPE_BDRAW, Mirror.Y, Shift.SHIFT_1));
				addImgSymbol(img, line);
	
				img = imgTypes.get(Image.variantKey(Image.TYPE_DRAW, Mirror.Y, Shift.SHIFT_1));
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
				
				img = imgTypes.get(Image.variantKey(Image.TYPE_BDRAW, Mirror.XY, Shift.SHIFT_0));
				addImgSymbol(img, line);
	
				img = imgTypes.get(Image.variantKey(Image.TYPE_DRAW, Mirror.XY, Shift.SHIFT_0));
				addImgSymbol(img, line);
	
				img = imgTypes.get(Image.variantKey(Image.TYPE_BDRAW, Mirror.XY, Shift.SHIFT_1));
				addImgSymbol(img, line);
	
				img = imgTypes.get(Image.variantKey(Image.TYPE_DRAW, Mirror.XY, Shift.SHIFT_1));
				addImgSymbol(img, line);
				flush(line);
				
			}		
		}

		flush(line);
		if (section != null) {
			asm.add(" ENDSECTION");
			asm.flush();
		}
		return;
	}

	/**
	 * One mapping frame : the page of the drawing code then its address, and
	 * the same pair for the erase code plus its cell count.
	 *
	 * The address is a symbol, so it has to be emitted as a word — an fcb
	 * would keep its low byte only. v1 had the value in hand and split it into
	 * two bytes itself.
	 */
	private void addImgSymbol(Image img, List<String> line) throws Exception {
		if (img == null) {
			return;
		}
		flush(line);                       // close the row of bytes in progress
		asm.addFcb(new String[]{pageSymbol(img, "")});
		asm.addFdb(new String[]{"adr_"+img.getFullName()});

		if (img.nb_cell != null) {
			asm.addFcb(new String[]{pageSymbol(img, AssemblyGenerator.ERASE_SUFFIXE)});
			asm.addFdb(new String[]{"adr_"+img.getFullName()+AssemblyGenerator.ERASE_SUFFIXE});
			asm.addFcb(new String[]{String.format("$%1$02X", img.nb_cell)}); // unsigned value
		}
		asm.flush();
	}

	/**
	 * The runtime feeds this byte straight to the cartridge window register, so
	 * it carries the RAM over cartridge bits, exactly as v1 wrote page + $60.
	 *
	 * Two ways to get there. Inside the unit holding the code, the load time
	 * linker adds the resolved page to a constant operand — one symbol for the
	 * whole set. Spread over several files, the page is asked per image and
	 * baked here : a literal costs nothing at load time, and it is the only
	 * form that can say two frames of one animation sit on different pages.
	 * The erase routine of an image is packed as its own part, so it is asked
	 * for separately — nothing guarantees it landed with its drawing code.
	 */
	private String pageSymbol(Image img, String suffix) throws Exception {
		if (pages != null) {
			return String.format("$%1$02X", (pages.of("adr_" + img.getFullName() + suffix) + 0x60) & 0xFF);
		}
		return file == null ? "$00" : file + "$PAGE+$60";
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
