import java.util.List;

public class Transcription {

    public static String getRule(String text, String ipa) {
        return "By default, '" + text + "' letters are transcribed as [" + ipa + "].";
    }

    public static Phoneme transcribeDefault(List<String> letters, String ipa) {
        return new Phoneme(letters.get(0), ipa, getRule(letters.get(0), ipa));
    }
}

