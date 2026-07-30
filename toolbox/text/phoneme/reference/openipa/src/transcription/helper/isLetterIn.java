import java.util.*;
import java.util.regex.*;
import java.util.stream.Collectors;

public class PhonemeChecker {

    public static boolean isPhonemeIn(
        Phoneme phoneme,
        Map<String, DatabaseIPA> ipa,
        RuleInputCategoryOrSubcategory step
    ) {
        List<String> possibleMatches = ipa.values().stream()
            .filter(e -> step.getIds().contains(
                (step.isRuleInputCategory() ? e.getCategory() : e.getSubcategory()) != null ? 
                (step.isRuleInputCategory() ? e.getCategory() : e.getSubcategory()) : -1
            ))
            .map(DatabaseIPA::getSymbol)
            .collect(Collectors.toList());

        if (phoneme == null || phoneme.getIpa() == null) {
            return possibleMatches.contains("");
        }

        String regex = String.join("", possibleMatches);
        char symbolToMatch = phoneme.getIpa().charAt(phoneme.getIpa().length() - 1);

        boolean isPhonemeInRegex = Pattern.compile("[" + regex + "]", Pattern.CASE_INSENSITIVE)
            .matcher(String.valueOf(symbolToMatch))
            .find();

        return isPhonemeInRegex;
    }

    // Uncomment and implement if needed
    // public static boolean isLetterInSubcategory(
    //     String char,
    //     List<Integer> subcategoryIds,
    //     Map<Integer, IPASubcategory> subcategories
    // ) {
    //     if (char == null || char.isEmpty()) return false;

    //     boolean hasMatch = false;
    //     for (Integer id : subcategoryIds) {
    //         if (!subcategories.containsKey(id)) continue;

    //         String regex = String.join("", subcategories.get(id).getLetters());

    //         if (Pattern.compile("[" + regex + "]", Pattern.CASE_INSENSITIVE)
    //             .matcher(char)
    //             .find()) {
    //             hasMatch = true;
    //         }
    //     }

    //     return hasMatch;
    // }
}
```

Note: You will need to define the `Phoneme`, `DatabaseIPA`, `RuleInputCategoryOrSubcategory`, and other related classes/interfaces in Java as per your TypeScript definitions.

