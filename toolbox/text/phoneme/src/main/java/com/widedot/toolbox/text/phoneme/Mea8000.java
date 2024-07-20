package com.widedot.toolbox.text.phoneme;

public class Mea8000 {

//  Voyelles
//  --------
//	Phonème /i/ : il ;
//	Phonème /e/ : blé ;
//	Phonème /ɛ/ : colère ;
//	Phonème /a/ : platte ;
//	Phonème /ɑ/ : pâte ;
//	Phonème /ɔ/ : mort ;
//	Phonème /o/ : chaud ;
//	Phonème /u/ : genou ;
//	Phonème /y/ : rue ;
//	Phonème /ø/ : peu ;
//	Phonème /œ/ : peur ;
//	Phonème /ə/ : le ;
//	Phonème /ɛ̃/ : plein ;
//	Phonème /ɑ̃/ : sans ;
//	Phonème /ɔ̃/ : bon ;
//	Phonème /œ̃/ : brun.

//	Semi-consonnes
//  --------------
//	Phonème /j/ : yeux ;
//	Phonème /w/ : oui ;
//	Phonème /ɥ/ : lui.

//	Consonnes
//  --------------
//	Phonème /p/ : père ;
//	Phonème /t/ : terre ;
//	Phonème /k/ : cou ;
//	Phonème /b/ : bon ;
//	Phonème /d/ : dans ;
//	Phonème /ɡ/ : gare ;
//	Phonème /f/ : feu ;
//	Phonème /s/ : sale ;
//	Phonème /ʃ/ : chat ;
//	Phonème /v/ : vous ;
//	Phonème /z/ : zéro ;
//	Phonème /ʒ/ : je ;
//	Phonème /l/ : lent ;
//	Phonème /ʁ/ : rue ;
//	Phonème /m/ : main ;
//	Phonème /n/ : nous ;
//	Phonème /ɲ/ : agneau.

//	Consonnes parfois ajoutées mais relevant d'emprunts aux langues étrangères
//  --------------------------------------------------------------------------
//	Phonème /h/ : hop ;
//	Phonème /ŋ/ : camping ;
//	Phonème /x/ : (jota espagnole, c'h breton et 'kh, plutôt prononcés /χ/ d'ailleurs).

	
/*
	.b            equ 13 ; ex. boule
	.d            equ 14 ; ex. domino
	.f            equ 15 ; ex. fort
	.g            equ 16 ; ex. gai
	.j            equ 17 ; ex. joie
	.k            equ 18 ; ex. carte
	.l            equ 19 ; ex. lumiere
	.m            equ 20 ; ex. maman
	.n            equ 21 ; ex. navire
	.p            equ 22 ; ex. papa
	.R            equ 23 ; ex. roule
	.r            equ 24 ; ex. lourd
	.S            equ 25 ; ex. sauce (s long)
	.t            equ 26 ; ex. tomate
	.v            equ 27 ; ex. valise
	.z            equ 28 ; ex. zoe
	.ch           equ 29 ; ex. charme
	.gn           equ 30 ; ex. bagne
	.s            equ 37 ; ex. histoire (s bref)
	.silence_32ms equ 38
	.silence_64ms equ 39
	*/
	
	//  Voyelles
	//  --------
	public static String[] IPA_i = {"i","i"};  // navire   
	public static String[] IPA_e = {"e","et"}; // école     
	public static String[] IPA_ɛ = {"ɛ","ai"}; // gai
	public static String[] IPA_a = {"a","a"};  // papa  
	public static String[] IPA_ɑ = {"ɑ","a"};  // ** pâte    
	public static String[] IPA_ɔ = {"ɔ","o"};  // bord    
	public static String[] IPA_o = {"o","O"};  // plateau   
	public static String[] IPA_u = {"u","ou"}; // loup   
	public static String[] IPA_y = {"y","u"};  // lune     
	public static String[] IPA_ø = {"ø","eu"}; // heureux     
	public static String[] IPA_œ = {"œ","eu"}; // ** peur    
	public static String[] IPA_ə = {"ə","e"};  // le    
	
	// Nasales
	// -------
	public static String[] IPA_ɛa = {"ɛ","in"}; // lapin   + manque accent IPA
	public static String[] IPA_ɑa = {"ɑ","an"}; // nathan  + manque accent IPA
	public static String[] IPA_ɔa = {"ɔ","on"}; // long    + manque accent IPA
	public static String[] IPA_œa = {"œ","in"}; // ** brun + manque accent IPA

	//	Semi-consonnes / Semi-voyelles
	//  ------------------------------
	//	Phonème /j/ : yeux ; !! a créer !!
	//	Phonème /w/ : oui ;  !! a créer !!
	//	Phonème /ɥ/ : lui.   !! a créer + lettre inversée IPA !!
	public static String[] IPA_aj = {"aj","ail"};  // travail 
	public static String[] IPA_ɛj = {"ɛj","eil"};  // vermeil
	public static String[] IPA_œj = {"œj","euil"}; // deuil
	public static String[] IPA_jɛ = {"jɛ","ien"};  // bien (accent nasal sur epsilon)
	public static String[] IPA_wa = {"wa","oi"};   // joie 
	public static String[] IPA_wɛ = {"wɛ","oin"};  // point (accent nasal sur epsilon)

//	Consonnes
//  --------------
//	Phonème /p/ : père ;
//	Phonème /t/ : terre ;
//	Phonème /k/ : cou ;
//	Phonème /b/ : bon ;
//	Phonème /d/ : dans ;
//	Phonème /ɡ/ : gare ;
//	Phonème /f/ : feu ;
//	Phonème /s/ : sale ;
//	Phonème /ʃ/ : chat ;
//	Phonème /v/ : vous ;
//	Phonème /z/ : zéro ;
//	Phonème /ʒ/ : je ;
//	Phonème /l/ : lent ;
//	Phonème /ʁ/ : rue ;
//	Phonème /m/ : main ;
//	Phonème /n/ : nous ;
//	Phonème /ɲ/ : agneau.

//	Consonnes parfois ajoutées mais relevant d'emprunts aux langues étrangères
//  --------------------------------------------------------------------------
//	Phonème /h/ : hop ;
//	Phonème /ŋ/ : camping ;
//	Phonème /x/ : (jota espagnole, c'h breton et 'kh, plutôt prononcés /χ/ d'ailleurs).
}
