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

package funkatronics.code.tactilewaves.dsp.toolbox;

/**
 * Implementation of the
 * <a href="http://audition.ens.fr/adc/pdf/2002_JASA_YIN.pdf">
 *     YIN Pitch Detection Algorithm
 * </a>
 * (PDA)
 *
 * @author Marco Martinez
 */

public class YIN {

	// do not allow instantiation
	private YIN() {}

    // The YIN threshold value (see paper)
    private static final double mThreshold = 0.2;

	/**
	 * Returns a pitch value in Hz or -1 if no pitch is detected
	 *
	 * @param buffer the sample buffer to analyze
	 * @param sampleRate the sample rate of the audio in the buffer
	 *
	 * @return a pitch value in Hz or -1 if no pitch is detected.
	 */
	public static float estimatePitch(float[] buffer, int sampleRate) {
		int tauEstimate;

		// Step 1/2
		float[] diff = YINdifference(buffer);

		// Step 3
		YINcumulativeMeanNormalizedDifference(diff);

		// Step 4
		tauEstimate = YINabsoluteThreshold(diff);

		if(tauEstimate == -1)
			return -1;

		// Step 6 (The paper does the steps in a weird order)
		tauEstimate = YINbestLocalEstimate(tauEstimate, diff);

		// Step 5
		float betterTau = YINparabolicInterpolation(tauEstimate, diff);

		//conversion to Hz
		return sampleRate/betterTau;

	}

	/**
	 * Returns a pitch value in Hz or -1 if no pitch is detected. Uses the {@link FFT} class to
	 * compute the auto correlation, which results in about a 90% speed increase at the cost of a
	 * small amount of accuracy
	 *
	 * @param buffer the sample buffer to analyze
	 * @param sampleRate the sample rate of the audio in the buffer
	 *
	 * @return a pitch value in Hz or -1 if no pitch is detected.
	 */
	public static float estimatePitchFast(float[] buffer, int sampleRate) {
		int tauEstimate;

		//step 2
		float[] diff = YINdifferenceFast(buffer);

		//step 3
		YINcumulativeMeanNormalizedDifference(diff);

		//step 4
		tauEstimate = YINabsoluteThreshold(diff);

		//step 6
		tauEstimate = YINbestLocalEstimate(tauEstimate, diff);

		//step 5
		if(tauEstimate != -1) {
			float betterTau = YINparabolicInterpolation(tauEstimate, diff);

			//conversion to Hz
			return sampleRate/betterTau;
		}

		return -1;
	}

    /**
     * Step 2 of YIN PDA: The YINdifference function
     */
    private static float[] YINdifference(float[] x){
		float[] result = new float[x.length/2];
		float delta;
		for(int tau = 1; tau < result.length; tau++){
			for(int j = 0; j < result.length; j++){
				delta = x[j] - x[j+tau];
				result[tau] += delta*delta;
			}
		}
        return result;
    }

	/**
	 * Step 2 of YIN PDA: The YINdifference function using autocorrelation via FFT
	 */
	private static float[] YINdifferenceFast(float[] x){
		float[] result = new float[x.length/2];
		// Calculate first energy term, so the rest can be calculated with a recursive formula
//		float rt0 = 0;
//		for(int j = 0; j < x.length/2; j++) {
//			rt0 += x[j]*x[j];
//		}

//		// YIN Autocorrelation using real FFT
//		// 1. FFT of data
//		float[] ReX = new float[x.length];
//		System.arraycopy(x, 0, ReX, 0, x.length);
//		float[] ImX = FFT.fft(ReX);
//
//
//		float[] ReY = new float[x.length];
//		// 2. Half of the data, disguised as a convolution kernel
//		for(int j = 0; j < result.length; j++) {
//			ReY[j] = x[result.length - 1 - j];
//		}
//		float[] ImY = FFT.fft(ReY);
//
//		// 3. Multiplication in frequency domain = convolution in time domain
//		for(int j = 0; j < x.length; j++) {
//			float temp = ReX[j];
//			ReX[j] = ReX[j]*ReY[j] - ImX[j]*ReY[j]; // real
//			ImX[j] = temp*ImY[j] + ImX[j]*ReY[j]; // imaginary
//		}
//
//		// 4. Back to time domain
//		FFT.ifft(ReX, ImX);

		float[] YINacf = FFT.autocorr(x);

		//float rtj = rt0;
		for(int tau = 1; tau < result.length; tau++) {
			// Recursively calculate next power term
			//rtj = rtj - x[tau-1]*x[tau-1];
			//rtj = rtj - x[tau-1]*x[tau-1] + x[tau+result.length]*x[tau+result.length];
			// Difference function according to Equation (7) in the YIN paper
			//result[tau] = (rt0 + rtj - 2*ReX[tau + result.length - 1])/(x.length - tau);
			result[tau] = (YINacf[0]/x.length - YINacf[tau]/(x.length - tau))*2048*1024;
		}

		return result;
	}

    /**
     * Step 3 of YIN PDA: The cumulative mean normalized YINdifference function
     */
    private static void YINcumulativeMeanNormalizedDifference(float[] diff) {
        int tau;
		diff[0] = 1;
        //start the running sum with the correct value:
        //the first value of the yinBuffer
        float runningSum = diff[1];
        //yinBuffer[1] is always 1
		diff[1] = 1;
        //now start at tau = 2
        for(tau = 2; tau < diff.length; tau++){
            runningSum += diff[tau];
			if (runningSum == 0) {
				diff[tau] = 1;
			} else {
				diff[tau] *= tau / runningSum;
			}
        }
    }

    /**
     * Step 4 of the YIN PDA
     */
    private static int YINabsoluteThreshold(float[] diff) {
        for(int T = 2; T < diff.length; T++){
            if(diff[T] < mThreshold){
                while(T+1 < diff.length && diff[T+1] < diff[T])
                    T++;
                return T;
            }
        }
        // no pitch found
		return -1;
    }

    /**
     * Step 5 of the YIN PDA: Refine the estimated tau value using parabolic interpolation
     * This is needed to detect higher frequencies more precisely.
     *
     * @param tauEstimate the estimated tau value.
	 *
     * @return a better, more precise tau value.
     */
    private static float YINparabolicInterpolation(int tauEstimate, float[] diff) {
        float s0, s1, s2;
        int x0 = (tauEstimate < 1) ? tauEstimate : tauEstimate - 1;
        int x2 = (tauEstimate + 1 < diff.length) ? tauEstimate + 1 : tauEstimate;
        if(x0 == tauEstimate)
            return (diff[tauEstimate] <= diff[x2]) ? tauEstimate : x2;
        if(x2 == tauEstimate)
            return (diff[tauEstimate] <= diff[x0]) ? tauEstimate : x0;
        s0 = diff[x0];
        s1 = diff[tauEstimate];
        s2 = diff[x2];
        return tauEstimate + 0.5f*(s2 - s0)/(2.f*s1 - s2 - s0);
    }

    /**
     * Step 6 of the YIN PDA
     */
    private static int YINbestLocalEstimate(int tauEstimate, float[] diff) {
		float min = 1000;
		int minTau = -1;
		int start = tauEstimate - tauEstimate/5;
		if(start < 0) start = 0;
		int end = tauEstimate + tauEstimate/5;
		if(end >= diff.length) end = diff.length-1;
        for(int tau = start; tau <= end; tau++) {
			if(diff[tau] < diff[tauEstimate]) {
				while(tau+1 < diff.length && diff[tau+1] < diff[tau])
					tau++;
				return tau;
			}else if(diff[tau] < min){
                min = diff[tau];
                minTau = tau;
            }
        }

        return minTau;
    }

}
