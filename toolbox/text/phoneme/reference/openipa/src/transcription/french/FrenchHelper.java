import java.util.Arrays;
import java.util.List;

public class Helper {
    private static final List<String> PRONOUNCED_CONSONANTS = Arrays.asList("c", "r", "f", "l");

    public static boolean isPronouncedConsonant(String consonant, boolean isFinal) {
        if (consonant == null || consonant.isEmpty()) return false;
        if (isFinal) {
            return PRONOUNCED_CONSONANTS.contains(consonant.toLowerCase());
        } else {
            return isConsonant(consonant);
        }
    }

    public static boolean isGlideFollowing(String letter, String nextletter, String nextlettersecond, String nextletterthird, String nextletterfourth) {
        boolean isMedialILL =
                nextletter.equals("i") &&
                nextlettersecond.equals("l") &&
                nextletterthird.equals("l") &&
                !isEndOfSentence(nextletterfourth);

        boolean isVowelIL =
                isVowel(letter) && nextletter.equals("i") && nextlettersecond.equals("l");

        return isMedialILL || isVowelIL;
    }

    public static boolean isNasalCanceling(String character) {
        if (character == null || character.isEmpty()) return false;
        return Arrays.asList("m", "n", "h").contains(character.toLowerCase()) || Letters.vowels.contains(character.toLowerCase());
    }

    public static boolean areNoMorePronouncedConsonants(List<String> charArray, int index) {
        int currentIndex = index;
        while (!isPronouncedConsonant(charArray.get(currentIndex), true) &&
                (isConsonant(charArray.get(currentIndex)) || isEndOfSentence(charArray.get(currentIndex)))) {
            if (isEndOfSentence(charArray.get(currentIndex))) return true;
            currentIndex++;
        }
        return false;
    }

    // Placeholder methods for isConsonant, isEndOfSentence, and isVowel
    private static boolean isConsonant(String character) {
        // Implementation needed
        return false;
    }

    private static boolean isEndOfSentence(String character) {
        // Implementation needed
        return false;
    }

    private static boolean isVowel(String character) {
        // Implementation needed
        return false;
    }
}

