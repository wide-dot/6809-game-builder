package com.widedot.toolbox.text.phoneme;

import java.util.ArrayList;
import java.util.List;

public class Mea8000 {

	// MEA8000 - IPA Mapping to French phonemes 3.3 (Parole et Micros)
	// ** Missing phoneme in asm table

	public static String SYMBOL_PREFIX = ".";
	public static String WORD_DELIMITER = "wordDelimiter";
	public static String END_DELIMITER = "endDelimiter";
	public static List<Element> symbols;
	static {
		symbols = new ArrayList<>();

		// Exceptions
		// ----------
		symbols.add(new Element("^aj", "ail"));  // travail
		symbols.add(new Element("^ɛj", "eil"));  // vermeil
		symbols.add(new Element("^œj", "euil")); // deuil
		symbols.add(new Element("^jɛ̃", "ien"));  // bien
		symbols.add(new Element("^wa", "oi"));   // joie
		symbols.add(new Element("^wɛ̃", "oin"));  // point

		// Nasales
		// -------
		symbols.add(new Element("^ɛ̃", "in")); // lapin
		symbols.add(new Element("^ɑ̃", "an")); // nathan
		symbols.add(new Element("^ɔ̃", "on")); // long
		symbols.add(new Element("^œ̃", "in")); // ** (un) brun
		
		// Voyelles
		// --------
		symbols.add(new Element("^i", "i"));  // navire
		symbols.add(new Element("^e", "et")); // école
		symbols.add(new Element("^ɛ", "ai")); // gai
		symbols.add(new Element("^a", "a"));  // papa
		symbols.add(new Element("^ɑ", "a"));  // ** (A) pâte
		symbols.add(new Element("^ɔ", "o"));  // bord
		symbols.add(new Element("^o", "O"));  // plateau
		symbols.add(new Element("^u", "ou")); // loup
		symbols.add(new Element("^y", "u"));  // lune
		symbols.add(new Element("^ø", "eu")); // heureux
		symbols.add(new Element("^œ", "eu")); // ** (EU) peur
		symbols.add(new Element("^ə", "e"));  // le

		// Semi-consonnes / Semi-voyelles
		// ------------------------------
		symbols.add(new Element("^j", "i"));  // ** (ye) yeux
		symbols.add(new Element("^w", "ou")); // ** (w) oui
		symbols.add(new Element("^µ", "u"));  // ** (U) lui

		// Consonnes
		// ---------
		symbols.add(new Element("^p", "p"));  // papa
		symbols.add(new Element("^t", "t"));  // tomate
		symbols.add(new Element("^k", "k"));  // carte
		symbols.add(new Element("^b", "b"));  // boule
		symbols.add(new Element("^d", "d"));  // domino
		symbols.add(new Element("^g", "g"));  // gai
		symbols.add(new Element("^f", "f"));  // fort
		symbols.add(new Element("^s", "S"));  // sauce
		symbols.add(new Element("^ʃ", "ch")); // charme
		symbols.add(new Element("^v", "v"));  // valise
		symbols.add(new Element("^z", "z"));  // zoe
		symbols.add(new Element("^ʒ", "j"));  // joie
		symbols.add(new Element("^l", "l"));  // lumière
		symbols.add(new Element("^ʁ", "R"));  // roule
		symbols.add(new Element("^r", "r"));  // lourd
		symbols.add(new Element("^m", "m"));  // maman
		symbols.add(new Element("^n", "n"));  // navire
		symbols.add(new Element("^ɲ", "gn")); // agneau

		// Ponctuation
		// -----------
		symbols.add(new Element("^\\.", "period"));
		symbols.add(new Element("^\\?", "questionMark"));
		symbols.add(new Element("^\\!", "exclamationMark"));
		symbols.add(new Element("^\\,", "comma"));
		symbols.add(new Element("^\\;", "semiColon"));
	}
}
