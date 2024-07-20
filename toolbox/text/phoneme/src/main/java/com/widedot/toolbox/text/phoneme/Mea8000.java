package com.widedot.toolbox.text.phoneme;

import java.util.HashMap;
import java.util.Map;

public class Mea8000 {

	// MEA8000 - IPA Mapping to French phonemes 3.3 (Parole et Micros)
	// ** Missing phoneme in asm table

	public static String SYMBOL_PREFIX = ".";
	private static Map<String, String> map;
	static {
		map = new HashMap<>();

		// Exceptions
		// ----------
		map.put("aj", "ail");  // travail
		map.put("ɛj", "eil");  // vermeil
		map.put("œj", "euil"); // deuil
		map.put("jɛ", "ien");  // bien (accent nasal sur epsilon)
		map.put("wa", "oi");   // joie
		map.put("wɛ", "oin");  // point (accent nasal sur epsilon)

		// Voyelles
		// --------
		map.put("i", "i");  // navire
		map.put("e", "et"); // école
		map.put("ɛ", "ai"); // gai
		map.put("a", "a");  // papa
		map.put("ɑ", "a");  // ** (A) pâte
		map.put("ɔ", "o");  // bord
		map.put("o", "O");  // plateau
		map.put("u", "ou"); // loup
		map.put("y", "u");  // lune
		map.put("ø", "eu"); // heureux
		map.put("œ", "eu"); // ** (EU) peur
		map.put("ə", "e");  // le

		// Nasales
		// -------
		map.put("ɛ̃", "in"); // lapin
		map.put("ɑ̃", "an"); // nathan
		map.put("ɔ̃", "on"); // long
		map.put("œ̃", "in"); // ** (un) brun

		// Semi-consonnes / Semi-voyelles
		// ------------------------------
		map.put("j", "i");  // ** (ye) yeux
		map.put("w", "ou"); // ** (w) oui
		map.put("µ", "u");  // ** (U) lui

		// Consonnes
		// ---------
		map.put("p", "p");  // papa
		map.put("t", "t");  // tomate
		map.put("k", "k");  // carte
		map.put("b", "b");  // boule
		map.put("d", "d");  // domino
		map.put("g", "g");  // gai
		map.put("f", "f");  // fort
		map.put("s", "S");  // sauce
		map.put("ʃ", "ch"); // charme
		map.put("v", "v");  // valise
		map.put("z", "z");  // zoe
		map.put("ʒ", "j");  // joie
		map.put("l", "l");  // lumière
		map.put("ʁ", "R");  // roule
		map.put("r", "r");  // lourd
		map.put("m", "m");  // maman
		map.put("n", "n");  // navire
		map.put("ɲ", "gn"); // agneau

		// Ponctuation
		// -----------
		map.put(" ", "wordDelimiter");
		map.put(".", "period");
		map.put("?", "questionMark");
		map.put("!", "exclamationMark");
		map.put(",", "comma");
		map.put(";", "semiColon");
	}
}
