import java.util.HashMap;
import java.util.Map;

class IPA {
    public static final String OPEN_E = "OPEN_E";
    public static final String CLOSED_Y = "CLOSED_Y";
    public static final String FLIPPED_R = "FLIPPED_R";
    public static final String SCHWA = "SCHWA";
    public static final String T = "T";
    public static final String M = "M";
    public static final String DARK_A = "DARK_A";
    public static final String BRIGHT_A = "BRIGHT_A";
    public static final String NASAL_A = "NASAL_A";
    public static final String J_GLIDE = "J_GLIDE";
    public static final String FRICATIVE_G = "FRICATIVE_G";
    public static final String CLOSED_MIXED_O = "CLOSED_MIXED_O";
    public static final String OPEN_O = "OPEN_O";
}

class ExceptionPhenome {
    String ipa;
    String rule;

    ExceptionPhenome(String ipa, String rule) {
        this.ipa = ipa;
        this.rule = rule;
    }
}

public class Exceptions {
    private static final Map<String, ExceptionPhenome> MerVerExceptions = new HashMap<>();
    private static final Map<String, ExceptionPhenome> OpenErExceptions = new HashMap<>();
    private static final Map<String, ExceptionPhenome> ChExceptions = new HashMap<>();
    private static final Map<String, ExceptionPhenome> FinalAiExceptions = new HashMap<>();
    private static final Map<String, ExceptionPhenome> AvoirExceptions = new HashMap<>();
    private static final Map<String, ExceptionPhenome> MedialIllExceptions = new HashMap<>();
    private static final Map<String, ExceptionPhenome> DarkOyAExceptions = new HashMap<>();
    private static final Map<String, ExceptionPhenome> MiscExceptions = new HashMap<>();
    private static final Map<String, ExceptionPhenome> NasalExceptions = new HashMap<>();
    private static final Map<String, ExceptionPhenome> ArticleExceptions = new HashMap<>();
    
    private static final Map<String, ExceptionPhenome> Exceptions = new HashMap<>();

    static {
        MerVerExceptions.put("mer", new ExceptionPhenome("mεɾ", Rules.MER_VER));
        MerVerExceptions.put("mers", new ExceptionPhenome("mεɾ", Rules.MER_VER));
        MerVerExceptions.put("vers", new ExceptionPhenome("vεɾ", Rules.MER_VER));
        MerVerExceptions.put("amer", new ExceptionPhenome("amεɾ", Rules.MER_VER));
        MerVerExceptions.put("amers", new ExceptionPhenome("amεɾ", Rules.MER_VER));
        MerVerExceptions.put("divers", new ExceptionPhenome("divεɾ", Rules.MER_VER));
        MerVerExceptions.put("envers", new ExceptionPhenome("ɑ̃vεɾ", Rules.MER_VER));
        MerVerExceptions.put("hiver", new ExceptionPhenome("ivεɾ", Rules.MER_VER));
        MerVerExceptions.put("hivers", new ExceptionPhenome("ivεɾ", Rules.MER_VER));
        MerVerExceptions.put("travers", new ExceptionPhenome("tɾavεɾ", Rules.MER_VER));
        MerVerExceptions.put("univers", new ExceptionPhenome("ynivεɾ", Rules.MER_VER));

        OpenErExceptions.put("cher", new ExceptionPhenome("ʃεɾ", Rules.OPEN_ER));
        OpenErExceptions.put("chers", new ExceptionPhenome("ʃεɾ", Rules.OPEN_ER));
        OpenErExceptions.put("enfer", new ExceptionPhenome("ɑ̃fεɾ", Rules.OPEN_ER));
        OpenErExceptions.put("éther", new ExceptionPhenome("etεɾ", Rules.OPEN_ER));
        OpenErExceptions.put("fer", new ExceptionPhenome("fεɾ", Rules.OPEN_ER));
        OpenErExceptions.put("fers", new ExceptionPhenome("fεɾ", Rules.OPEN_ER));
        OpenErExceptions.put("fier", new ExceptionPhenome("fjεɾ", Rules.OPEN_ER));
        OpenErExceptions.put("hier", new ExceptionPhenome("jεɾ", Rules.OPEN_ER));
        OpenErExceptions.put("sers", new ExceptionPhenome("sεɾ", Rules.OPEN_ER));

        ChExceptions.put("écho", new ExceptionPhenome("eko", Rules.HARD_CH));
        ChExceptions.put("chœur", new ExceptionPhenome("kœɾ", Rules.HARD_CH));
        ChExceptions.put("choeur", new ExceptionPhenome("kœɾ", Rules.HARD_CH));

        FinalAiExceptions.put("balai", new ExceptionPhenome("balε", Rules.FINAL_AI));
        FinalAiExceptions.put("lai", new ExceptionPhenome("lε", Rules.FINAL_AI));
        FinalAiExceptions.put("mai", new ExceptionPhenome("mε", Rules.FINAL_AI));
        FinalAiExceptions.put("rai", new ExceptionPhenome("ɾε", Rules.FINAL_AI));
        FinalAiExceptions.put("vrai", new ExceptionPhenome("vɾε", Rules.FINAL_AI));

        AvoirExceptions.put("eu", new ExceptionPhenome(IPA.CLOSED_Y, Rules.AVOIR));
        AvoirExceptions.put("eus", new ExceptionPhenome(IPA.CLOSED_Y, Rules.AVOIR));
        AvoirExceptions.put("eut", new ExceptionPhenome(IPA.CLOSED_Y, Rules.AVOIR));
        AvoirExceptions.put("eût", new ExceptionPhenome(IPA.CLOSED_Y, Rules.AVOIR));
        AvoirExceptions.put("eurent", new ExceptionPhenome(IPA.CLOSED_Y + IPA.FLIPPED_R + IPA.SCHWA, Rules.AVOIR));
        AvoirExceptions.put("eusse", new ExceptionPhenome(IPA.CLOSED_Y + IPA.S + IPA.SCHWA, Rules.AVOIR));
        AvoirExceptions.put("eussent", new ExceptionPhenome(IPA.CLOSED_Y + IPA.S + IPA.SCHWA, Rules.AVOIR));
        AvoirExceptions.put("eutes", new ExceptionPhenome(IPA.CLOSED_Y + IPA.T + IPA.SCHWA, Rules.AVOIR));
        AvoirExceptions.put("eûtes", new ExceptionPhenome(IPA.CLOSED_Y + IPA.T + IPA.SCHWA, Rules.AVOIR));
        AvoirExceptions.put("eûmes", new ExceptionPhenome(IPA.CLOSED_Y + IPA.M + IPA.SCHWA, Rules.AVOIR));
        AvoirExceptions.put("eues", new ExceptionPhenome(IPA.CLOSED_Y + IPA.SCHWA, Rules.AVOIR));
        AvoirExceptions.put("eue", new ExceptionPhenome(IPA.CLOSED_Y + IPA.SCHWA, Rules.AVOIR));

        MedialIllExceptions.put("mille", new ExceptionPhenome("mil" + IPA.SCHWA, Rules.MEDIAL_ILL));
        MedialIllExceptions.put("ville", new ExceptionPhenome("vil" + IPA.SCHWA, Rules.MEDIAL_ILL));
        MedialIllExceptions.put("tranquille", new ExceptionPhenome("t" + IPA.FLIPPED_R + IPA.NASAL_A + "kil" + IPA.SCHWA, Rules.MEDIAL_ILL));
        MedialIllExceptions.put("oscille", new ExceptionPhenome(IPA.OPEN_O + "sil" + IPA.SCHWA, Rules.MEDIAL_ILL));

        DarkOyAExceptions.put("trois", new ExceptionPhenome("t" + IPA.FLIPPED_R + "w" + IPA.DARK_A, Rules.DARK_OY_A));
        DarkOyAExceptions.put("bois", new ExceptionPhenome("bw" + IPA.DARK_A, Rules.DARK_OY_A));
        DarkOyAExceptions.put("voix", new ExceptionPhenome("vw" + IPA.DARK_A, Rules.DARK_OY_A));

        MiscExceptions.put("et", new ExceptionPhenome("e", "'et' (French for 'and') is pronounced as [e] to make a distinction between it and 'es/est' (French for 'is'), which are pronounced [ε]."));
        MiscExceptions.put("es", new ExceptionPhenome(IPA.OPEN_E, "'es' and 'est' (French for 'is') are pronounced as [" + IPA.OPEN_E + "] to make a distinction between it and 'et' (French for 'and'), which are pronounced [e]."));
        MiscExceptions.put("est", new ExceptionPhenome(IPA.OPEN_E, "'es' and 'est' (French for 'is') are pronounced as [" + IPA.OPEN_E + "] to make a distinction between it and 'et' (French for 'and'), which are pronounced [e]."));
        MiscExceptions.put("dessous", new ExceptionPhenome("d" + IPA.SCHWA + "su", Rules.EXCEPTION));
        MiscExceptions.put("dessus", new ExceptionPhenome("d" + IPA.SCHWA + "sy", Rules.EXCEPTION));
        MiscExceptions.put("femme", new ExceptionPhenome("famə", Rules.BRIGHT_A));
        MiscExceptions.put("fixe", new ExceptionPhenome("fiksə", Rules.EXCEPTION));
        MiscExceptions.put("fosse", new ExceptionPhenome("fosə", Rules.EXCEPTION));
        MiscExceptions.put("grosse", new ExceptionPhenome("gɾosə", Rules.EXCEPTION));
        MiscExceptions.put("luxe", new ExceptionPhenome("lyksə", Rules.EXCEPTION));
        MiscExceptions.put("lys", new ExceptionPhenome("lis", Rules.EXCEPTION));
        MiscExceptions.put("maison", new ExceptionPhenome("m(e)zõ", Rules.EXCEPTION));
        MiscExceptions.put("monsieur", new ExceptionPhenome("m" + IPA.SCHWA + "sj" + IPA.CLOSED_MIXED_O, Rules.EXCEPTION));
        MiscExceptions.put("o", new ExceptionPhenome("o", Rules.EXCEPTION));
        MiscExceptions.put("oh", new ExceptionPhenome("o", Rules.EXCEPTION));
        MiscExceptions.put("pays", new ExceptionPhenome("pei", Rules.EXCEPTION));
        MiscExceptions.put("ressemble", new ExceptionPhenome("r" + IPA.SCHWA + "s" + IPA.NASAL_A + "bl" + IPA.SCHWA, Rules.EXCEPTION));
        MiscExceptions.put("secret", new ExceptionPhenome("s" + IPA.SCHWA + "k" + IPA.FLIPPED_R + IPA.OPEN_E, Rules.EXCEPTION + " " + Notes.FINAL_E_HALFCLOSED));
        MiscExceptions.put("solennelle", new ExceptionPhenome("sɔlanεlə", Rules.EXCEPTION));

        NasalExceptions.put("enivré", new ExceptionPhenome(IPA.NASAL_A + "niv" + IPA.FLIPPED_R + "e", Rules.PRONOUNCED_NASAL_N));
        NasalExceptions.put("enneigé", new ExceptionPhenome(IPA.NASAL_A + "n(e)" + IPA.FRICATIVE_G + "e", Rules.NASAL_TWO_N));
        NasalExceptions.put("ennui", new ExceptionPhenome(IPA.NASAL_A + "n" + IPA.Y_GLIDE + "i", Rules.NASAL_TWO_N));
        NasalExceptions.put("amen", new ExceptionPhenome("am" + IPA.OPEN_E + "n", Rules.NO_NASAL));
        NasalExceptions.put("carmen", new ExceptionPhenome("ka" + IPA.FLIPPED_R + "m" + IPA.OPEN_E + "n", Rules.NO_NASAL));
        NasalExceptions.put("en", new ExceptionPhenome(IPA.NASAL_A, Rules.UNUSAL_NASAL));
        NasalExceptions.put("encens", new ExceptionPhenome(IPA.NASAL_A + "s" + IPA.NASAL_A, Rules.EXCEPTION));
        NasalExceptions.put("gens", new ExceptionPhenome(IPA.FRICATIVE_G + IPA.NASAL_A, Rules.EXCEPTION));
        NasalExceptions.put("poulenc", new ExceptionPhenome("pul" + IPA.NASAL_E + "k", Rules.EXCEPTION));
        NasalExceptions.put("album", new ExceptionPhenome("alb" + IPA.OPEN_O + "m", Rules.NO_NASAL));
        NasalExceptions.put("aquarium", new ExceptionPhenome("aka" + IPA.FLIPPED_R + IPA.J_GLIDE + IPA.OPEN_O + "m", Rules.NO_NASAL));
        NasalExceptions.put("géranium", new ExceptionPhenome(IPA.FRICATIVE_G + "e" + IPA.FLIPPED_R + "an" + IPA.J_GLIDE + IPA.OPEN_O + "m", Rules.NO_NASAL));

        ArticleExceptions.put("ces", new ExceptionPhenome("se", Rules.ARTICLES));
        ArticleExceptions.put("des", new ExceptionPhenome("de", Rules.ARTICLES));
        ArticleExceptions.put("les", new ExceptionPhenome("le", Rules.ARTICLES));
        ArticleExceptions.put("mes", new ExceptionPhenome("me", Rules.ARTICLES));
        ArticleExceptions.put("ses", new ExceptionPhenome("se", Rules.ARTICLES));
        ArticleExceptions.put("tes", new ExceptionPhenome("te", Rules.ARTICLES));

        Exceptions.putAll(MerVerExceptions);
        Exceptions.putAll(OpenErExceptions);
        Exceptions.putAll(ChExceptions);
        Exceptions.putAll(FinalAiExceptions);
        Exceptions.putAll(AvoirExceptions);
        Exceptions.putAll(MedialIllExceptions);
        Exceptions.putAll(DarkOyAExceptions);
        Exceptions.putAll(NasalExceptions);
        Exceptions.putAll(ArticleExceptions);
        Exceptions.putAll(MiscExceptions);
    }

    public static Map<String, ExceptionPhenome> getExceptions() {
        return Exceptions;
    }
}


