package com.widedot.toolbox.graphics.compiler;

import java.awt.image.BufferedImage;
import java.awt.image.DataBufferByte;
import java.awt.image.ColorModel;
import java.io.File;
import java.util.HashMap;
import javax.imageio.ImageIO;

import com.widedot.toolbox.graphics.compiler.encoder.Encoder;
import com.widedot.toolbox.graphics.compiler.encoder.bdraw.AssemblyGenerator;
import com.widedot.toolbox.graphics.compiler.encoder.draw.SimpleAssemblyGenerator;
import com.widedot.toolbox.graphics.compiler.encoder.rle.MapRleEncoder;
import com.widedot.toolbox.graphics.compiler.encoder.zx0.ZX0Encoder;
import com.widedot.toolbox.graphics.compiler.transformer.mirror.Mirror;
import com.widedot.toolbox.graphics.compiler.transformer.shift.Shift;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class Image {
	
	// image types
	public static final String TYPE_DRAW  = "draw";
	public static final String TYPE_BDRAW = "bdraw";
	public static final String TYPE_RLE   = "rle";
	public static final String TYPE_ZX0   = "zx0";
	
	public static final int TYPE_DRAW_INT  = 0;
	public static final int TYPE_BDRAW_INT = 1;
	public static final int TYPE_RLE_INT   = 2;
	public static final int TYPE_ZX0_INT   = 3;
	
	public static final HashMap<String, Integer> typeId = new HashMap<String, Integer>() {
		private static final long serialVersionUID = 1L;
		{
			put(TYPE_DRAW, TYPE_DRAW_INT);
			put(TYPE_BDRAW, TYPE_BDRAW_INT);
			put(TYPE_RLE, TYPE_RLE_INT);
			put(TYPE_ZX0, TYPE_ZX0_INT);
		}
	};
	
	public static final String[] typeLabel = new String[]{"D", "B", "R", "Z"};

	// center types
	public static final String POSITION_CENTER   = "center";
	public static final String POSITION_TOP_LEFT = "top-left";
	public static final String POSITION_3QTRC    = "3qtr-center";	
	
	public static final int POSITION_CENTER_INT   = 0;
	public static final int POSITION_TOP_LEFT_INT = 1;
	public static final int POSITION_3QTRC_INT    = 2;	
	
	public static final HashMap<String, Integer> positionId = new HashMap<String, Integer>() {
		private static final long serialVersionUID = 1L;
		{
			put(POSITION_CENTER, POSITION_CENTER_INT);
			put(POSITION_TOP_LEFT, POSITION_TOP_LEFT_INT);
			put(POSITION_3QTRC, POSITION_3QTRC_INT);
		}
	};
	
	public String name;
	public String variant;
	public int type;
	public int mirror;
	public int shift;
	public int position;	
	public int coordinate;
	public Integer nb_cell;
	
	private BufferedImage image;
	public ColorModel colorModel;
	private int width;
	private int height;
	
	private byte[][] pixels;
	private byte[][] data;
	
	// image rectangular bounds, without accounting transparent pixels
	public int x1_offset; // offset from center to the image left position (trimmed of transparent pixels)
	public int y1_offset; // offset from center to the image top position (trimmed of transparent pixels)	
	public int x_size;    // image width for non transparent pixels		
	public int y_size;    // image height for non transparent pixels		
	
	// transparency flags
	public boolean alpha;     // true if at least one pixel is transparent	
	public boolean evenAlpha; // true if at least one pixel is transparent on even lines
	public boolean oddAlpha;  // true if at least one pixel is transparent on odd lines	

	// plane flags (is a plane empty ?)
	private boolean plane0_empty;
	private boolean plane1_empty;	
	
	public Integer index;
	
	public Image(String imageName, Integer imageIndex, String imageFile, String encoderType, String encoderMirror, Integer encoderShift, String encoderPosition) {
		try {
			image = ImageIO.read(new File(imageFile));
			name = imageName;
			type = typeId.get(encoderType);
			mirror = Mirror.getId(encoderMirror);
			shift = encoderShift;
			
			variant = typeLabel[type]+Mirror.label[mirror]+encoderShift;
			width = image.getWidth();
			height = image.getHeight();
			colorModel = image.getColorModel();
			int pixelSize = colorModel.getPixelSize();
			plane0_empty = true;
			plane1_empty = true;
			index = imageIndex;
			nb_cell = null;

			// process images
			if (pixelSize == 8) {
				image = Mirror.transform(image, mirror);
				image = Shift.transform(image, encoderShift);
				prepareImages();
			} else {
				log.info("unsupported file format for " + imageFile + " ,pixel size:  " + pixelSize + " (should be 8).");
				throw new Exception ("png file format error.");
			}

		} catch (Exception e) {
			e.printStackTrace();
			System.out.println(e);
		}
	}
	
	// TODO - create n method as transformers
	// pad image to memory width
	// create n memory planes by vertical interlace or bitplanes
	// add alpha transparency info to image, based on color index 0
	// maintain a plane empty table
	// set a coordinate variable based on position
	// calcul des flags transparency, odd et even
	// calcul x et y offset en fonction du type de positionnement (centre, top left ...)		
	
	public void prepareImages() {
		// sépare l'image en deux parties pour la RAM A et RAM B
		// ajoute les pixels transparents pour constituer une image linéaire de largeur 2x80px
		int paddedImage = 80*height;
		pixels = new byte[2][paddedImage];
		data = new byte[2][paddedImage];
		boolean even = true;		
		plane0_empty = true;
		plane1_empty = true;

		switch (position) {
			case POSITION_CENTER_INT   : coordinate = (int)((Math.ceil(height/2.0)-1)*40) +  width/8; break;
			case POSITION_TOP_LEFT_INT : coordinate = 0; break;
			case POSITION_3QTRC_INT    : coordinate = (int)((Math.ceil(height*3.0/4.0)-1)*40) +  width/8; break; 
		}	
		
		// Position de début et de fin de chaque sous-image
		int startIndex = 0;		
		int endIndex = startIndex + width*(height-1) + (width-1);
		
		int indexDest = 0;
		int curLine = 0;
		int page = 0;		
		int x_Min = 160;
		int x_Max = -1;
		int y_Min = 200;
		int y_Max = -1;			
		boolean firstPixel = true;
		
		int index = startIndex;
		int endLineIndex = startIndex + width;

		even = false; // 
		alpha = false;
		evenAlpha = false;
		oddAlpha = false;
		
		while (index <= endIndex) { // Parcours de tous les pixels de l'image
			
			// Ecriture des pixels 2 à 2
			pixels[page][indexDest] = (byte) (((DataBufferByte) image.getRaster().getDataBuffer()).getElem(index));
			if (pixels[page][indexDest] == 0) {
				data[page][indexDest] = 0;
				alpha = true;
				if (even) {
					evenAlpha = true;
				} else {
					oddAlpha = true;
				}
			} else {
				if (page == 0 && pixels[page][indexDest] > 0) {
					plane0_empty = false;
				} else if (page == 1 && pixels[page][indexDest] > 0) {
					plane1_empty = false;
				}
				
				data[page][indexDest] = (byte) (pixels[page][indexDest]-1);
				
				// Calcul des offset et size de l'image
				if (firstPixel) {
					firstPixel = false;
					switch (position) {
						case POSITION_CENTER_INT   : y1_offset = curLine-(height-1)/2; break;
						case POSITION_TOP_LEFT_INT : y1_offset = 0; break;
						case POSITION_3QTRC_INT    : y1_offset = curLine-(height-1)*3/4; break;
					}						
				}
				if (indexDest*2+page*2-(160*curLine) < x_Min) {
					x_Min = indexDest*2+page*2-(160*curLine);
					switch (position) {
						case POSITION_CENTER_INT   : x1_offset = x_Min-(width/2); break;
						case POSITION_TOP_LEFT_INT : x1_offset = 0; break;
						case POSITION_3QTRC_INT    : x1_offset = 0; break;
					}						
				}
				if (indexDest*2+page*2-(160*curLine) > x_Max) {
					x_Max = indexDest*2+page*2-(160*curLine);
				}
				if (curLine < y_Min) {
					y_Min = curLine;
				}
				if (curLine > y_Max) {
					y_Max = curLine;
				}
				x_size = x_Max-x_Min;
				y_size = y_Max-y_Min;
			}
			index++;

			if (index == endLineIndex) {
				curLine++;
				index = width * curLine;
				endLineIndex = index + width;
				indexDest = 80*curLine;
				page = 0;
				even = !even;
			} else {
				pixels[page][indexDest+1] = (byte) (((DataBufferByte) image.getRaster().getDataBuffer()).getElem(index));
				if (pixels[page][indexDest+1] == 0) {
					data[page][indexDest+1] = 0;
					alpha = true;
					if (even) {
						evenAlpha = true;
					} else {
						oddAlpha = true;
					}					
				} else {
				
					if (page == 0 && pixels[page][indexDest+1] > 0) {
						plane0_empty = false;
					} else if (page == 1 && pixels[page][indexDest+1] > 0) {
						plane1_empty = false;
					}						
					data[page][indexDest+1] = (byte) (pixels[page][indexDest+1]-1);
					
					// Calcul des offset et size de l'image
					if (firstPixel) {
						firstPixel = false;
						switch (position) {
							case POSITION_CENTER_INT   : y1_offset = curLine-(height-1)/2; break;
							case POSITION_TOP_LEFT_INT : y1_offset = 0; break;
							case POSITION_3QTRC_INT    : y1_offset = curLine-(height-1)*3/4; break;
						}							
					}
					if (indexDest*2+page*2+1-(160*curLine) < x_Min) {
						x_Min = indexDest*2+page*2+1-(160*curLine);
						switch (position) {
							case POSITION_CENTER_INT   : x1_offset = x_Min-(width/2); break;
							case POSITION_TOP_LEFT_INT : x1_offset = 0; break;
							case POSITION_3QTRC_INT    : x1_offset = 0; break;
						}					
					}
					if (indexDest*2+page*2+1-(160*curLine) > x_Max) {
						x_Max = indexDest*2+page*2+1-(160*curLine);
					}
					if (curLine < y_Min) {
						y_Min = curLine;						
					}
					if (curLine > y_Max) {
						y_Max = curLine;
					}		
					x_size = x_Max-x_Min;
					y_size = y_Max-y_Min;	
				}
				index++;

				// Alternance des banques RAM A et RAM B
				if (page == 0) {
					page = 1;
				} else {
					page = 0;
					indexDest = indexDest+2;
				}

				if (index == endLineIndex) {
					curLine++;
					index = width * curLine;
					endLineIndex = index + width;
					indexDest = 80*curLine;
					page = 0;
					even = !even;
				}
			}
		}
	}
	
	public void encode(String outputDir) throws Exception {
		
	    File directory = new File(outputDir);
	    if (! directory.exists()){
	        directory.mkdirs();
	    }
		
		Encoder e;
		switch (type) {
			case TYPE_DRAW_INT: e = new SimpleAssemblyGenerator(this, outputDir, SimpleAssemblyGenerator._NO_ALPHA); break;
			case TYPE_BDRAW_INT: e = new AssemblyGenerator(this, outputDir); break;
			case TYPE_RLE_INT: e = new MapRleEncoder(this, outputDir); break;
			case TYPE_ZX0_INT: e = new ZX0Encoder(this, outputDir); break;
			default: log.error("Unrecognized image type: "+type); return;
		}
		
		e.generateCode();
	}
	
	public int getCenterOffset() {
		switch (width % 8) {
			case 0 : return 0;
			case 1 : return 1;
			case 2 : return 0;
			case 3 : return 1;
			case 4 : return 2;
			case 5 : return 2;
			case 6 : return 3;
			case 7 : return 3;
		}
		return 0;
	}
	
	public byte[] getSubImagePixels(int ramPage) {
		return pixels[ramPage];
	}

	public byte[] getSubImageData(int ramPage) {
		return data[ramPage];
	}

	public String getName() {
		return name;
	}
	
	public String getVariant() {
		return variant;
	}
	
	public String getFullName() {
		return name+"_"+variant;
	}

	public int getSubImageX1Offset() {
		return x1_offset;
	}	
	
	public int getSubImageY1Offset() {
		return y1_offset;
	}

	public int getSubImageXSize() {
		return x_size;
	}

	public int getSubImageYSize() {
		return y_size;
	}
	
	public boolean getAlpha() {
		return alpha;
	}	
	
	public boolean getOddAlpha() {
		return oddAlpha;
	}	
	
	public boolean getEvenAlpha() {
		return evenAlpha;
	}		
	
	public int getCoordinate() {
		return coordinate;
	}
	
	public boolean isPlane0Empty() {
		return plane0_empty;
	}
	
	public boolean isPlane1Empty() {
		return plane1_empty;
	}	
}