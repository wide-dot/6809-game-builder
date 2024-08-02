/*
 * ----------------------------------------------------------------------------)
 *                                                                            /
 *     _________  ________  ________ _________  ___  ___       _______       (
 *   |\___   ___\\   __  \|\   ____\\___   ___\\  \|\  \     |\  ___ \        \
 *   \|___ \  \_\ \  \|\  \ \  \___\|___ \  \_\ \  \ \  \    \ \   __/|        )
 *        \ \  \ \ \   __  \ \  \       \ \  \ \ \  \ \  \    \ \  \_|/__     /
 *         \ \  \ \ \  \ \  \ \  \____   \ \  \ \ \  \ \  \____\ \  \_|\ \   (
 *          \ \__\ \ \__\ \__\ \_______\  \ \__\ \ \__\ \_______\ \_______\   \
 *           \|__|  \|__|\|__|\|_______|   \|__|  \|__|\|_______|\|_______|    )
 *        ___       __   ________  ___      ___ _______   ________            /
 *       |\  \     |\  \|\   __  \|\  \    /  /|\  ___ \ |\   ____\          (
 *       \ \  \    \ \  \ \  \|\  \ \  \  /  / | \   __/|\ \  \___|_          \
 *        \ \  \  __\ \  \ \   __  \ \  \/  / / \ \  \_|/_\ \_____  \          )
 *         \ \  \|\__\_\  \ \  \ \  \ \    / /   \ \  \_|\ \|____|\  \        /
 *          \ \____________\ \__\ \__\ \__/ /     \ \_______\____\_\  \      (
 *           \|____________|\|__|\|__|\|__|/       \|_______|\_________\      \
 *                                                          \|_________|       )
 *                                                                            /
 *                                                                           (
 *                                                                            \
 * ----------------------------------------------------------------------------)
 *                                                                            /
 *                                                                           (
 *           Tactile Waves - a Java library for sensory substitution          \
 *          developed by Marco Martinez at Colorado State University.          )
 *                                                                            /
 *                                                                           (
 *                                                                            \
 * ----------------------------------------------------------------------------)
 *                                                                            /
 *                                                                           (
 *                    Copyright (C) 2017 Marco Martinez                       \
 *                                                                             )
 *                       funkatronicsmail@gmail.com                           /
 *                                                                           (
 *                                                                            \
 * ----------------------------------------------------------------------------)
 *                                                                            /
 *    This program is free software: you can redistribute it and/or modify   (
 *    it under the terms of the GNU General Public License as published by    \
 *     the Free Software Foundation, either version 3 of the License, or       )
 *                   (at your option) any later version.                      /
 *                                                                           (
 *       This program is distributed in the hope that it will be useful,      \
 *       but WITHOUT ANY WARRANTY; without even the implied warranty of        )
 *        MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the        /
 *                 GNU General Public License for more details               (
 *                                                                            \
 *     You should have received a copy of the GNU General Public License       )
 *    along with this program. If not, see <http://www.gnu.org/licenses/>.    /
 *                                                                           (
 *                                                                            \
 * ____________________________________________________________________________)
 */

package funkatronics.code.tactilewaves.dsp;

import java.util.ArrayList;
import java.util.List;

import funkatronics.code.tactilewaves.dsp.toolbox.Filter;
import funkatronics.code.tactilewaves.dsp.toolbox.LPC;
import funkatronics.code.tactilewaves.dsp.toolbox.Window;

/**
 * Processor Class that extracts formant frequencies from an audio signal
 *
 * @author Marco Martinez
 */

public class FormantExtractor implements WaveProcessor {

	// The number of formants to estimate
	private int mNumFormants;

	/**
	 * Construct a new {@code FormantExtractor} with the default number of formants (4)
	 */
	public FormantExtractor() {
		// Use default number of formants = 4
		mNumFormants = 4;
	}

	/** Construct a new {@code FormantExtractor}
	 *
	 * @param numFormants the number of formants to estimate (note: you may want to set this a bit
	 *                       higher than the actual number of formants you wish to estimate, e.g. if
	 *                       you want the first 3 formants, you may get more accurate results by
	 *                       requesting 4-6 formants from the {@code FormantExtractor})
	 */
	public FormantExtractor(int numFormants) {
		mNumFormants = numFormants;
	}

    public boolean process(WaveFrame frame) {
		// Window
		float[] x = Window.hamming(frame.getSamples());
		// Pre-Emphasis filtering
		x = Filter.preEmphasis(x);
    	// Get list of formant (frequency, bandwidth) pairs
        double[][] formants = LPC.estimateFormants(x, mNumFormants, frame.getSampleRate());
        // Prune the formant list for valid formants
        List<Float> formList = new ArrayList<Float>();
        List<Float> formBandList = new ArrayList<Float>();
        
        for(int i = 0; i < formants.length; i++) {
        	// Valid formants
            if(formants[i][0] > 90.0 && formants[i][0] < 3600.0 && formants[i][1] < 1500.0) {
            	formList.add((float) formants[i][0]);
            	formBandList.add((float) formants[i][1]);
            }
        }
        // Copy list of formants back to a feature vector (float array)
		float[] formFreqs = new float[formList.size()];
        for(int i = 0; i < formList.size(); i++) {
        	formFreqs[i] = formList.get(i);
        }
        
		float[] formBands = new float[formBandList.size()];
        for(int i = 0; i < formBandList.size(); i++) {
        	formBands[i] = formBandList.get(i);
        }
        // Add the feature vector of valid formants to the frame
        frame.addFeature("Formants Frequency", formFreqs);
        frame.addFeature("Formants Bandwidth", formBands);
        return true;
    }

    public void processingFinished() {}
}
