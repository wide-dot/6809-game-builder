package com.widedot.m6809.gamebuilder.util.graphics;

import java.awt.image.BufferedImage;
import java.awt.image.DataBufferByte;
import java.awt.image.ColorModel;
import java.io.File;
import java.util.HashMap;
import javax.imageio.ImageIO;
import lombok.extern.slf4j.Slf4j;

@Slf4j
public class Image {
	
	public String name;
	public String type;
	public int nb_cell;
	
	private BufferedImage image;
	ColorModel colorModel;
	private int width; // largeur totale de l'image
	private int height; // longueur totale de l'image
	
	private boolean plane0_empty;
	private boolean plane1_empty;	

	private byte[][] pixels;
	private byte[][] data;
	int x1_offset; // position haut gauche de l'image par rapport au centre
	int y1_offset; // position haut gauche de l'image par rapport au centre		
	int x_size; // largeur de l'image en pixel (sans les pixels transparents)		
	int y_size; // hauteur de l'image en pixel (sans les pixels transparents)		
	boolean alpha; // vrai si l'image contient au moins un pixel transparent	
	boolean evenAlpha; // vrai si l'image contient au moins un pixel transparent sur les lignes paires
	boolean oddAlpha; // vrai si l'image contient au moins un pixel transparent sur les lignes impaires	
	public int center; // position du centre de l'image (dans le référentiel pixels)
	
	public static final int CENTER = 0;
	public static final int TOP_LEFT = 1;
	public static final int TILE8x16 = 2;	
	public static final HashMap<String, Integer> colorModes = new HashMap<String, Integer>() {
		private static final long serialVersionUID = 1L;
		{
			put("CENTER", CENTER);
			put("TOP_LEFT", TOP_LEFT);
			put("TILE8x16", TILE8x16);
		}
	};
	
	public Image(String tag, String variant, String file, int centerMode) {
		try {
			image = ImageIO.read(new File(file));
			name = tag;
			type = variant;
			width = image.getWidth();
			height = image.getHeight();
			colorModel = image.getColorModel();
			int pixelSize = colorModel.getPixelSize();
			plane0_empty = true;
			plane1_empty = true;

			if (pixelSize == 8) {
				prepareImages(false, centerMode);
			} else {
				log.info("unsupported file format for " + file + " ,pixel size:  " + pixelSize + " (should be 8).");
				throw new Exception ("png file format error.");
			}

		} catch (Exception e) {
			e.printStackTrace();
			System.out.println(e);
		}
	}

	public void prepareImages(boolean onePixelOffset, int locationRef) {
		// sépare l'image en deux parties pour la RAM A et RAM B
		// ajoute les pixels transparents pour constituer une image linéaire de largeur 2x80px
		int paddedImage = 80*height;
		pixels = new byte[2][paddedImage];
		data = new byte[2][paddedImage];
		boolean even = true;		
		plane0_empty = true;
		plane1_empty = true;

		switch (locationRef) {
			case CENTER   : center = (int)((Math.ceil(height/2.0)-1)*40) +  width/8; break;
			case TOP_LEFT : center = 0; break;
			case TILE8x16 : center = (int)((Math.ceil(height*3.0/4.0)-1)*40) +  width/8; break; 
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
					switch (locationRef) {
						case CENTER   : y1_offset = curLine-(height-1)/2; break;
						case TOP_LEFT : y1_offset = 0; break;
						case TILE8x16 : y1_offset = curLine-(height-1)*3/4; break;
					}						
				}
				if (indexDest*2+page*2-(160*curLine) < x_Min) {
					x_Min = indexDest*2+page*2-(160*curLine);
					switch (locationRef) {
						case CENTER   : x1_offset = x_Min-(width/2); break;
						case TOP_LEFT : x1_offset = 0; break;
						case TILE8x16 : x1_offset = 0; break;
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
						switch (locationRef) {
							case CENTER   : y1_offset = curLine-(height-1)/2; break;
							case TOP_LEFT : y1_offset = 0; break;
							case TILE8x16 : y1_offset = curLine-(height-1)*3/4; break;
						}							
					}
					if (indexDest*2+page*2+1-(160*curLine) < x_Min) {
						x_Min = indexDest*2+page*2+1-(160*curLine);
						switch (locationRef) {
							case CENTER   : x1_offset = x_Min-(width/2); break;
							case TOP_LEFT : x1_offset = 0; break;
							case TILE8x16 : x1_offset = 0; break;
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
		
		if (onePixelOffset) {
			byte pixelSave = 0;
			byte dataSave = 0;
			// Décalage de l'image de 1px à droite pour chaque ligne
			for (int y = 0; y < height; y++) {
				for (int x = 79; x >= 1; x -= 2) {
					if (x == 79) {
						// Le pixel en fin de ligne revient au début de cette ligne
						pixelSave = pixels[1][x + (80 * y)];
						dataSave = data[1][x + (80 * y)];
					} else {
						pixels[0][(x + 1) + (80 * y)] = pixels[1][x + (80 * y)];
						data[0][(x + 1) + (80 * y)] = data[1][x + (80 * y)];
					}

					pixels[1][x + (80 * y)] = pixels[1][(x - 1) + (80 * y)];
					data[1][x + (80 * y)] = data[1][(x - 1) + (80 * y)];

					pixels[1][(x - 1) + (80 * y)] = pixels[0][x + (80 * y)];
					data[1][(x - 1) + (80 * y)] = data[0][x + (80 * y)];

					pixels[0][x + (80 * y)] = pixels[0][(x - 1) + (80 * y)];
					data[0][x + (80 * y)] = data[0][(x - 1) + (80 * y)];

					if (x == 1) {
						// Le pixel en fin de ligne revient au début de cette ligne
						pixels[0][0 + (80 * y)] = pixelSave;
						data[0][0 + (80 * y)] = dataSave;
					}
				}
			}
		}
	}
	
	public static int getCenterOffset(int width) {
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
	
	public String getType() {
		return type;
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
	
	public int getCenter() {
		return center;
	}
	
	public boolean isPlane0Empty() {
		return plane0_empty;
	}
	
	public boolean isPlane1Empty() {
		return plane1_empty;
	}	
}