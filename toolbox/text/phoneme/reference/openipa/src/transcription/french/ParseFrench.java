import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import static your.package.Exceptions;
import static your.package.FrenchHelper.isPronouncedConsonant;
import static your.package.FrenchNotes;
import static your.package.FrenchRules;
import static your.package.parseLetters.ParseA;
import static your.package.parseLetters.ParseB;
import static your.package.parseLetters.ParseC;
import static your.package.parseLetters.ParseD;
import static your.package.parseLetters.ParseE;
import static your.package.parseLetters.ParseF;
import static your.package.parseLetters.ParseG;
import static your.package.parseLetters.ParseH;
import static your.package.parseLetters.ParseI;
import static your.package.parseLetters.ParseJ;
import static your.package.parseLetters.ParseL;
import static your.package.parseLetters.ParseM;
import static your.package.parseLetters.ParseN;
import static your.package.parseLetters.ParseO;
import static your.package.parseLetters.ParseP;
import static your.package.parseLetters.ParseQ;
import static your.package.parseLetters.ParseR;
import static your.package.parseLetters.ParseS;
import static your.package.parseLetters.ParseT;
import static your.package.parseLetters.ParseU;
import static your.package.parseLetters.ParseV;
import static your.package.parseLetters.ParseX;
import static your.package.parseLetters.ParseY;
import static your.package.parseLetters.ParseZ;
import static your.package.parseLetters.ParseŒ;
import static your.package.constants.Interfaces.Result;
import static your.package.constants.Interfaces.Phoneme;
import static your.package.constants.Interfaces.ParseLetterProps;
import static your.package.constants.IPA;
import static your.package.constants.Template;
import static your.package.state.editor.FrenchTranscriptionOptions;
import static your.package.util.Helper.getCharArray;
import static your.package.util.Helper.isConsonant;
import static your.package.util.Helper.isVowel;
import static your.package.util.Helper.getNextWord;
import static your.package.util.Helper.isPunctuation;
import static your.package.util.Helper.isEndOfSentence;

public class FrenchParser {

    public static Result parseFrench(String text, FrenchTranscriptionOptions options) {
        boolean shouldAnalyzeLiason = options.shouldAnalyzeLiason.value;
        boolean shouldAnalyzeElision = options.shouldAnalyzeElision.value;

        char[] charArray = getCharArray(text);
        Result result = Template.getResultTemplate();

        String previousPhoneme = "";
        boolean startOfNewWord = true;

        for (int index = 0; index < charArray.length; index++) {
            char letter = charArray[index];
            Phoneme phoneme = new Phoneme(letter, String.valueOf(letter), Rules.UNKNOWN);
            int indexToAdd = 0;

            List<Character> nextletter = new ArrayList<>();

            // Do not transcribe '
            for (int i = 0; i < 10; i++) {
                if (index + i < charArray.length && charArray[index + i] != '\'') {
                    nextletter.add(charArray[index + i]);
                }
            }

            ParseLetterProps parseProps = new ParseLetterProps(phoneme, index, indexToAdd, charArray, nextletter, previousPhoneme);

            switch (letter) {
                case 'a':
                case 'â':
                case 'à':
                    phoneme = ParseA(parseProps);
                    break;
                case 'b':
                    phoneme = ParseB(parseProps);
                    break;
                case 'c':
                case 'ç':
                    phoneme = ParseC(parseProps);
                    break;
                case 'd':
                    phoneme = ParseD(parseProps);
                    break;
                case 'e':
                case 'é':
                case 'è':
                case 'ê':
                case 'ë':
                    phoneme = ParseE(parseProps);
                    break;
                case 'f':
                    phoneme = ParseF(parseProps);
                    break;
                case 'g':
                    phoneme = ParseG(parseProps);
                    break;
                case 'h':
                    phoneme = ParseH(parseProps);
                    break;
                case 'i':
                case 'î':
                case 'ï':
                    phoneme = ParseI(parseProps);
                    break;
                case 'j':
                    phoneme = ParseJ(parseProps);
                    break;
                case 'l':
                    phoneme = ParseL(parseProps);
                    break;
                case 'm':
                    phoneme = ParseM(parseProps);
                    break;
                case 'n':
                    phoneme = ParseN(parseProps);
                    break;
                case 'o':
                case 'ô':
                    phoneme = ParseO(parseProps);
                    break;
                case 'œ':
                    phoneme = ParseŒ(parseProps);
                    break;
                case 'p':
                    phoneme = ParseP(parseProps);
                    break;
                case 'q':
                    phoneme = ParseQ(parseProps);
                    break;
                case 'r':
                    phoneme = ParseR(parseProps);
                    break;
                case 's':
                    phoneme = ParseS(parseProps);
                    break;
                case 't':
                    phoneme = ParseT(parseProps);
                    break;
                case 'u':
                case 'û':
                    phoneme = ParseU(parseProps);
                    break;
                case 'v':
                    phoneme = ParseV(parseProps);
                    break;
                case 'x':
                    phoneme = ParseX(parseProps);
                    break;
                case 'y':
                    phoneme = ParseY(parseProps);
                    break;
                case 'z':
                    phoneme = ParseZ(parseProps);
                    break;

                // PUNCTUATION
                case ',':
                case ';':
                case '!':
                case '.':
                case '?':
                case '(':
                case ')':
                case '-':
                    phoneme = new Phoneme(letter, String.valueOf(letter), Rules.NONE);
                    startOfNewWord = true;
                    break;
                case '\'':
                case '’':
                    phoneme = new Phoneme(letter, "", Rules.NONE);
                    startOfNewWord = true;
                    break;
                case ' ':
                    result.lines.get(result.lines.size() - 1).words.add(new Word(new ArrayList<>()));
                    startOfNewWord = true;
                    break;
                case '\n':
                    result.lines.add(new Line(new ArrayList<>()));
                    startOfNewWord = true;
                    break;
            }
            indexToAdd = phoneme.text.length() - 1;

            Line currentLine = result.lines.get(result.lines.size() - 1);
            Word currentWord = currentLine.words.get(currentLine.words.size() - 1);

            // Check for exceptions
            if (startOfNewWord) {
                Object[] wordAndIndex = getNextWord(index, charArray);
                String word = (String) wordAndIndex[0];
                int newIndex = (int) wordAndIndex[1];
                String wordNoPunctuation = String.join("", getCharArray(word).stream().filter(char -> !isPunctuation(char)).toArray(Character[]::new));

                if (Exceptions.containsKey(wordNoPunctuation)) {
                    phoneme = new Phoneme(word, Exceptions.get(wordNoPunctuation).ipa, Exceptions.get(wordNoPunctuation).rule);
                    char precedingCharacter = charArray[index];
                    boolean hasPrecedingPunctuation = isPunctuation(precedingCharacter);
                    if (hasPrecedingPunctuation) {
                        currentWord.syllables.add(new Phoneme(precedingCharacter, "", Rules.NONE));
                    }
                    index = newIndex;
                }
            }
            startOfNewWord = false;

            index += indexToAdd;

            // Analyze Elision
            if (shouldAnalyzeElision) {
                if (nextletter.size() > 1 && nextletter.get(1) != '\n') {
                    if (phoneme.ipa.equals(IPA.SCHWA) && isEndOfSentence(nextletter.get(1)) && isVowel(nextletter.get(2))) {
                        phoneme = new Phoneme(phoneme.text, "", Rules.ELISION);
                    }
                }
            }

            Phoneme liasonPhoneme = null;
            // Analyze Liason
            if (shouldAnalyzeLiason) {
                char lastCharacter = phoneme.text.charAt(phoneme.text.length() - 1);
                char nextCharacter = (index + 1 < charArray.length) ? charArray[index + 1] : '\0';
                char nextCharacterSecond = (index + 2 < charArray.length) ? charArray[index + 2] : '\0';
                if (nextCharacter != '\n') {
                    if (!isPronouncedConsonant(lastCharacter, true) && isConsonant(lastCharacter) && lastCharacter != 's' && isEndOfSentence(nextCharacter) && isVowel(nextCharacterSecond)) {
                        liasonPhoneme = new Phoneme(" ", lastCharacter + IPA.UNDERTIE, phoneme.rule + Notes.LIASON);
                    } else if (lastCharacter == 's' && isEndOfSentence(nextCharacter) && isVowel(nextCharacterSecond)) {
                        liasonPhoneme = new Phoneme(" ", IPA.Z + IPA.UNDERTIE, Rules.S_LIASON);
                    }
                }
            }

            currentWord.syllables.add(phoneme);
            previousPhoneme = phoneme.ipa.charAt(phoneme.ipa.length() - 1);

            if (liasonPhoneme != null) {
                currentWord.syllables.add(liasonPhoneme);
                previousPhoneme = liasonPhoneme.ipa.charAt(liasonPhoneme.ipa.length() - 1);
            }

            // Analyze final IPA syllable
            if (!phoneme.text.equals("est") && !phoneme.text.equals("es")) {
                Phoneme previousSyllable = currentWord.syllables.get(currentWord.syllables.size() - 1);
                if (previousSyllable.ipa.length() == 0) {
                    if (currentWord.syllables.size() > 1) {
                        previousSyllable = currentWord.syllables.get(currentWord.syllables.size() - 2);
                    }
                }
                if (previousSyllable != null && isEndOfSentence(charArray[index + 1])) {
                    char previousIPA = previousSyllable.ipa.charAt(previousSyllable.ipa.length() - 1);
                    if (previousIPA != '\0') {
                        if (previousIPA == IPA.OPEN_E) {
                            previousSyllable.ipa = IPA.CLOSED_E;
                            previousSyllable.rule += Notes.FINAL_E_HALFCLOSED;
                        }
                    }
                }
            }

            // Analyze vocalic harmonization
            if (isEndOfSentence(nextletter.size() > 1 ? nextletter.get(1) : '\0') ||
                (indexToAdd == 1 && isEndOfSentence(nextletter.size() > 2 ? nextletter.get(2) : '\0')) ||
                (indexToAdd == 2 && isEndOfSentence(nextletter.size() > 3 ? nextletter.get(3) : '\0')) ||
                (indexToAdd == 3 && isEndOfSentence(nextletter.size() > 4 ? nextletter.get(4) : '\0'))) {
                boolean closedFrontVowelFound = false;
                boolean closedMixedVowelFound = false;
                for (int j = currentWord.syllables.size() - 1; j >= 0; j--) {
                    Phoneme currentIPA = currentWord.syllables.get(j);
                    for (int k = currentIPA.ipa.length() - 1; k >= 0; k--) {
                        char symbol = currentIPA.ipa.charAt(k);
                        if (symbol == IPA.CLOSED_E || symbol == IPA.CLOSED_I || symbol == IPA.CLOSED_Y) {
                            closedFrontVowelFound = true;
                        } else if (symbol == IPA.CLOSED_MIXED_O) {
                            closedMixedVowelFound = true;
                        }

                        if (closedFrontVowelFound) {
                            if (symbol == IPA.OPEN_E && (currentIPA.text.equals("ai") || currentIPA.text.equals("aî") || currentIPA.text.equals("ay") || currentIPA.text.equals("ei") || currentIPA.text.equals("ê"))) {
                                currentWord.syllables.set(j, new Phoneme(currentIPA.text, "(" + IPA.CLOSED_E + ")", Rules.VOCALIC_HARMONIZATION_E));
                            }
                        } else if (closedMixedVowelFound) {
                            if (symbol == IPA.OPEN_MIXED_O) {
                                currentWord.syllables.set(j, new Phoneme(currentIPA.text, "(" + IPA.CLOSED_MIXED_O + ")", Rules.VOCALIC_HARMONIZATION_E));
                            }
                        }
                    }
                }
            }
        }
        return result;
    }
}


