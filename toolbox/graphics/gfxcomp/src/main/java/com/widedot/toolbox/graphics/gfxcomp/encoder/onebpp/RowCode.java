package com.widedot.toolbox.graphics.gfxcomp.encoder.onebpp;

import java.util.ArrayList;
import java.util.List;

import com.widedot.m6809.util.asm.Register;

/**
 * Row-walking code emitter shared by the 1bpp draw (OR) and clear (zero)
 * routines.
 *
 * U enters at the canvas reference byte/row (see Image.getMonoOrigin) and
 * walks the packed box row by row : one LEAU per row that has ink, then every
 * access uses a 0..15 offset (5-bit indexed, no extra cycle) instead of a
 * 16-bit one. Two adjacent ink bytes are moved as one D pair (LDD/ORA/ORB/STD
 * for a draw, STD of zero for a clear). ANDA before ORA is redundant for an
 * ink-only plane (AND ~v then OR v is just OR v), so a draw is LDD/OR/STD.
 * U is left wherever the walk ends : the 1bpp callers do not read it back
 * (clear1 keeps no background cells).
 */
final class RowCode {

	final List<String> code = new ArrayList<String>();
	int cycles;
	int size;

	private int ubase; // U offset from the entry value, in screen bytes

	private RowCode() {
	}

	private void leau(int target) throws Exception {
		int delta = target - ubase;
		if (delta == 0) {
			return;
		}
		code.add("\tLEAU " + delta + ",U");
		cycles += Register.costIndexedLEA + Register.getIndexedOffsetCost(delta);
		size += Register.sizeIndexedLEA + Register.getIndexedOffsetSize(delta);
		ubase = target;
	}

	private void ld(int reg, String mnemonic, int off) throws Exception {
		code.add("\t" + mnemonic + " " + off + ",U");
		cycles += Register.costIndexedLD[reg] + Register.getIndexedOffsetCost(off);
		size += Register.sizeIndexedLD[reg] + Register.getIndexedOffsetSize(off);
	}

	private void st(int reg, String mnemonic, int off) throws Exception {
		code.add("\t" + mnemonic + " " + off + ",U");
		cycles += Register.costIndexedST[reg] + Register.getIndexedOffsetCost(off);
		size += Register.sizeIndexedST[reg] + Register.getIndexedOffsetSize(off);
	}

	private void ldImm(int reg, String mnemonic, String imm) {
		code.add("\t" + mnemonic + " #$" + imm);
		cycles += Register.costImmediateLD[reg];
		size += Register.sizeImmediateLD[reg];
	}

	private void orImm(int reg, String mnemonic, int v) {
		code.add("\t" + mnemonic + " #$" + String.format("%02X", v));
		cycles += Register.costImmediateOR[reg];
		size += Register.sizeImmediateOR[reg];
	}

	/** OR the packed rows into the screen : rows [0,rows) x bytes [0,rowBytes) of imm */
	static RowCode draw(int[][] imm, int rows, int rowBytes, int origin) throws Exception {
		RowCode rc = new RowCode();
		for (int r = 0; r < rows; r++) {
			int c = 0;
			while (c < rowBytes && imm[r][c] == 0) {
				c++;
			}
			if (c == rowBytes) {
				continue;
			}
			rc.leau(origin + r * BitPack.LINE_BYTES);
			while (c < rowBytes) {
				int v = imm[r][c];
				if (v == 0) {
					c++;
					continue;
				}
				boolean pair = c + 1 < rowBytes && imm[r][c + 1] != 0;
				if (pair) {
					int v2 = imm[r][c + 1];
					if (v == 0xFF && v2 == 0xFF) {
						rc.ldImm(Register.D, "LDD", "FFFF");
					} else {
						rc.ld(Register.D, "LDD", c);
						if (v != 0) {
							rc.orImm(Register.A, "ORA", v);
						}
						rc.orImm(Register.B, "ORB", v2);
					}
					rc.st(Register.D, "STD", c);
					c += 2;
				} else {
					if (v == 0xFF) {
						rc.ldImm(Register.A, "LDA", "FF");
					} else {
						rc.ld(Register.A, "LDA", c);
						rc.orImm(Register.A, "ORA", v);
					}
					rc.st(Register.A, "STA", c);
					c++;
				}
			}
		}
		return rc;
	}

	/** zero exactly the bytes a draw of the same rows touches */
	static RowCode clear(int[][] imm, int rows, int rowBytes, int origin) throws Exception {
		RowCode rc = new RowCode();
		boolean zeroed = false;
		for (int r = 0; r < rows; r++) {
			int c = 0;
			while (c < rowBytes && imm[r][c] == 0) {
				c++;
			}
			if (c == rowBytes) {
				continue;
			}
			if (!zeroed) {
				rc.ldImm(Register.D, "LDD", "0000");
				zeroed = true;
			}
			rc.leau(origin + r * BitPack.LINE_BYTES);
			while (c < rowBytes) {
				if (imm[r][c] == 0) {
					c++;
					continue;
				}
				if (c + 1 < rowBytes && imm[r][c + 1] != 0) {
					rc.st(Register.D, "STD", c);
					c += 2;
				} else {
					rc.st(Register.A, "STA", c);
					c++;
				}
			}
		}
		return rc;
	}
}
