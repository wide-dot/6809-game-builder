import java.util.ArrayList;
import java.util.List;

class RuleInputString {
    public List<String> text;

    public RuleInputString(List<String> text) {
        this.text = text;
    }
}

public class MatchStringInput {

    public static String matchStringInput(RuleInputString step, String text, int index) {
        // Loop through possible string matches
        List<String> stringMatches = new ArrayList<>();
        for (String possibleMatch : step.text) {
            String characters = text.substring(index, Math.min(index + possibleMatch.length(), text.length())).toLowerCase();
            if (characters.equals(possibleMatch)) {
                stringMatches.add(characters);
            }
        }

        // If there is a string match, return the longest match
        if (!stringMatches.isEmpty()) {
            return stringMatches.stream().reduce((longestMatch, currentMatch) -> {
                if (longestMatch == null) return currentMatch;
                if (currentMatch.length() > longestMatch.length()) return currentMatch;
                return longestMatch;
            }).orElse("");
        }

        // Otherwise
        return null;
    }

    public static void main(String[] args) {
        // Example usage
        List<String> possibleMatches = new ArrayList<>();
        possibleMatches.add("hello");
        possibleMatches.add("world");
        RuleInputString step = new RuleInputString(possibleMatches);
        String text = "helloworld";
        int index = 0;

        String result = matchStringInput(step, text, index);
        System.out.println(result); // Output: hello
    }
}


