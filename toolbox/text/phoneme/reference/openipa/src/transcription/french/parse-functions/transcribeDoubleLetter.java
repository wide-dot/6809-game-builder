import java.util.List;

public class Transcription {

    public static String getDoubleLetterRule(String letter, String ipa) {
        return "Double '" + letter + letter + "' consonants are transcribed as a single [" + ipa + "].";
    }

    public static Phoneme transcribeDoubleLetter(Phoneme phoneme, List<String> letters, String ipa) {
        if (letters.get(0).equals(letters.get(1))) {
            if (ipa == null) ipa = letters.get(0);
            return new Phoneme(letters.get(0) + letters.get(1), ipa, getDoubleLetterRule(letters.get(0), ipa));
        }
        return phoneme;
    }
}

