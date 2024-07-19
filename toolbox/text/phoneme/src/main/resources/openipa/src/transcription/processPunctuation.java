import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

class Phoneme {
    String text;
    String ipa;
    String rule;

    Phoneme(String text, String ipa, String rule) {
        this.text = text;
        this.ipa = ipa;
        this.rule = rule;
    }
}

class Syllable {
    // Assuming Syllable has some properties, add them here
}

class Word {
    List<Syllable> syllables = new ArrayList<>();

    Word() {
        this.syllables = new ArrayList<>();
    }
}

class Line {
    List<Word> words = new ArrayList<>();

    Line() {
        this.words = new ArrayList<>();
    }
}

class Result {
    List<Line> lines = new ArrayList<>();

    Result() {
        this.lines = new ArrayList<>();
    }
}

public class ProcessPunctuation {
    private static final List<String> PUNCTUATION = Arrays.asList(",", ";", "!", ".", "(", ")");
    private static final List<String> END_OF_WORD_CHARACTERS = Arrays.asList(" ");
    private static final List<String> END_OF_LINE_CHARACTERS = Arrays.asList("\n");

    public static Result processPunctuation(String[] charArray, int index, Result result) {
        String charStr = charArray[index];
        Phoneme phoneme = null;

        if (PUNCTUATION.contains(charStr)) {
            phoneme = new Phoneme(charStr, charStr, "");
        }

        if (END_OF_WORD_CHARACTERS.contains(charStr)) {
            result.lines.get(result.lines.size() - 1).words.add(new Word());
        }

        if (END_OF_LINE_CHARACTERS.contains(charStr)) {
            Line newLine = new Line();
            newLine.words.add(new Word());
            result.lines.add(newLine);
        }

        return result;
    }

    public static void main(String[] args) {
        // Example usage
        String[] charArray = {",", " ", "\n"};
        Result result = new Result();
        result.lines.add(new Line());
        result.lines.get(0).words.add(new Word());

        for (int i = 0; i < charArray.length; i++) {
            result = processPunctuation(charArray, i, result);
        }

        // Print result for verification
        System.out.println("Lines: " + result.lines.size());
        for (Line line : result.lines) {
            System.out.println("Words in line: " + line.words.size());
        }
    }
}


