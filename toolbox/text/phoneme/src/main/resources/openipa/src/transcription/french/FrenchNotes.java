import java.util.HashMap;
import java.util.Map;

public class Notes {
    public static final Map<String, String> NOTES;

    static {
        NOTES = new HashMap<>();
        NOTES.put("FINAL_E_HALFCLOSED", " Note: Final [" + IPA.OPEN_E + "] vowels are closed to a half-closed [" + IPA.OPEN_E + "] or a fully closed [" + IPA.CLOSED_E + "]. In practice, pronunciation is closer to [" + IPA.CLOSED_E + "], so that is what has been notated here.");
        NOTES.put("GLIDE_FOLLOWING", " Note: medial '-ill' and '-il' glides are transcribed separately from a preceding vowel.");
        NOTES.put("LIASON", " Note: This normally silent consonant is pronounced in this case due to liason, as the following word begins with a vowel. Liason rules are complex, so take this transcription with a grain of salt.");
    }
}

