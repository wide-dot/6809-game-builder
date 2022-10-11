package com.widedot.toolbox.graphics.compiler.encoder.draw;

import java.util.ArrayList;
import java.util.List;

import com.widedot.toolbox.graphics.compiler.encoder.draw.pattern.Pattern;
import com.widedot.toolbox.graphics.compiler.encoder.draw.pattern.Pattern_01;
import com.widedot.toolbox.graphics.compiler.encoder.draw.pattern.Pattern_0101;
import com.widedot.toolbox.graphics.compiler.encoder.draw.pattern.Pattern_0110;
import com.widedot.toolbox.graphics.compiler.encoder.draw.pattern.Pattern_0111;
import com.widedot.toolbox.graphics.compiler.encoder.draw.pattern.Pattern_10;
import com.widedot.toolbox.graphics.compiler.encoder.draw.pattern.Pattern_1001;
import com.widedot.toolbox.graphics.compiler.encoder.draw.pattern.Pattern_1010;
import com.widedot.toolbox.graphics.compiler.encoder.draw.pattern.Pattern_1011;
import com.widedot.toolbox.graphics.compiler.encoder.draw.pattern.Pattern_11;
import com.widedot.toolbox.graphics.compiler.encoder.draw.pattern.Pattern_1101;
import com.widedot.toolbox.graphics.compiler.encoder.draw.pattern.Pattern_1110;
import com.widedot.toolbox.graphics.compiler.encoder.draw.pattern.Pattern_1111;
import com.widedot.toolbox.graphics.compiler.encoder.draw.pattern.Pattern_111111;
import com.widedot.toolbox.graphics.compiler.encoder.draw.pattern.Pattern_11111111;
import com.widedot.toolbox.graphics.compiler.encoder.draw.pattern.Pattern_1111111111;
import com.widedot.toolbox.graphics.compiler.encoder.draw.pattern.Pattern_111111111111;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class PatternFinder {
	// Recherche les patterns applicables à une image
	// Créée une solution avec ces patterns
	// Chaque pattern est associé un un code ASM
	
	private byte[] image;
	private Pattern[] snippets = {new Pattern_111111111111(), new Pattern_1111111111(), new Pattern_11111111(), new Pattern_111111(), new Pattern_1111(), new Pattern_0111(), new Pattern_1011(), new Pattern_1101(), new Pattern_1110(), new Pattern_0101(), new Pattern_1001(), new Pattern_0110(), new Pattern_1010(), new Pattern_11(), new Pattern_01(), new Pattern_10()}; // Trier du plus rapide au plus lent
	private List<Solution> solutions;

	public PatternFinder (byte[] data) {
		image = data;
	}

	public void buildCode (boolean isForward) throws Exception {
		if (isForward) {
			//log..debug("Recherche de motifs, lecture vers l'avant.");
			this.solutions = buildCodeForward(0);
		} else {
			//log..debug("Recherche de motifs, lecture vers l'arrière.");
			this.solutions = buildCodeRearward(this.image.length-2); // -1 (fin de tableau) + -1 (pixel par paire)
		}
	}

	private List<Solution> buildCodeRearward(int i) {
		List<Solution> localSolution =  new ArrayList<Solution>();

		while (i >= 0 && image[i] == 0x00 && image[i+1] == 0x00) {
			i -= 2;
		}

		if (i < 0) {
			localSolution.add(new Solution());
			return localSolution;
		}

		for (Pattern snippet : snippets) {
			if (snippet.matchesRearward(image, i)) {
				List<Solution> bottomSolution = buildCodeRearward(i-snippet.getNbPixels());
				if (!bottomSolution.isEmpty()) {
					for (Solution eachSolution : bottomSolution) {
						eachSolution.add(snippet, i/2);
						localSolution.add(eachSolution);
					}
				}
				// retirer ce return permet d'avoir toutes les combinaisons possibles au lieu de une seule
				// trop de combinaisons, implémenter une méthode pour éliminer les combinaisons non viables
				// dès le départ afin de réduire leur nombre
				return localSolution;
			}
		}
		return localSolution;
	}
	
	private List<Solution> buildCodeForward(int i) {
		List<Solution> localSolution =  new ArrayList<Solution>();

		while (i+1 < image.length && image[i] == 0x00 && image[i+1] == 0x00) {
			i += 2;
		}

		if (i >= image.length) {
			localSolution.add(new Solution());
			return localSolution;
		}

		for (Pattern snippet : snippets) {
			if (snippet.matchesForward(image, i)) {
				List<Solution> bottomSolution = buildCodeForward(i+snippet.getNbPixels());
				if (!bottomSolution.isEmpty()) {
					for (Solution eachSolution : bottomSolution) {
						eachSolution.add(snippet, i/2);
						localSolution.add(eachSolution);
					}
				}
				// retirer ce return permet d'avoir toutes les combinaisons possibles au lieu de une seule
				// trop de combinaisons, implémenter une méthode pour �liminer les combinaisons non viables
				// dès le départ afin de réduire leur nombre
				return localSolution;
			}
		}
		return localSolution;
	}

	public List<Solution> getSolutions() {
		return solutions;
	}
}
