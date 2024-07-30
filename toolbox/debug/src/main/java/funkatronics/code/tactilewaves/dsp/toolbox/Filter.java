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

import java.util.Arrays;
import java.util.logging.Logger;

/**
 * Class for filtering data series using recursive filters
 * <p>
 *     Butterworth, Critically Damped, and Bessel filter types are supported via instantiation with
 *     an arbitrary number of poles. A static method for filtering using any provided filter
 *     coefficients is available for custom filtering.
 * </p>
 *
 * @author Marco Martinez
 */

public class Filter {

    private static final Logger LOG = Logger.getLogger(Filter.class.getSimpleName());

    // pi constant, because it is used a lot in this class
    private final static double pi = Math.PI;

    // Integer constants that represent the different filter types
    /**
     * A Butterworth filter
     */
    public static final int ALLPOLE_BUTTERWORTH = 0;

    /**
     * A Critically Damped filter
     */
    public static final int ALLPOLE_CRITICALLY_DAMPED = 1;

    /**
     * A Bessel filter
     */
    public static final int ALLPOLE_BESSEL = 2;

	/**
	 * An analog modeled low-pass filter
	 */
	public static final int BIQUAD_LPF = 4;

	/**
	 * An analog modeled high-pass filter
	 */
	public static final int BIQUAD_HPF = 5;

	/**
	 * An analog modeled band-pass filter
	 */
	public static final int BIQUAD_BPF = 6;

	/**
	 * An analog modeled notch (band-reject) filter
	 */
	public static final int BIQUAD_NOTCH = 7;

	/**
	 * An analog modeled all-pass filter
	 */
	public static final int BIQUAD_APF = 8;

	/**
	 * An analog modeled peakingEQ filter
	 */
	public static final int BIQUAD_PEQ = 9;

	/**
	 * An analog modeled low-shelf filter
	 */
	public static final int BIQUAD_LSH = 10;

	/**
	 * An analog modeled high-shelf filter
	 */
	public static final int BIQUAD_HSH = 11;

    // Arrays to hold filter coefficients
    private double[] mA;
    private double[] mB;

	/**
	 * Construct a Filter object with the supplied coefficients
	 *
	 * @param b the numerator filter coefficients
	 * @param a the denominator filter coefficients
	 */
	public Filter(float[] b, float[] a){
		mA = new double[a.length];
		for(int i = 0; i < a.length; i++) {
			mA[i] = a[i];
		}
		mB = new double[b.length];
		for(int i = 0; i < b.length; i++) {
			mB[i] = b[i];
		}
	}

    /**
     * Construct a Filter object with the supplied coefficients
     *
	 * @param b the numerator filter coefficients
	 * @param a the denominator filter coefficients
     */
    public Filter(double[] b, double[] a){
        mA = a;
        mB = b;
    }

	/**
	 * Get the numerator (feedforward) filter coefficients of this Filter instance
	 *
	 * @return the numerator filter coefficients
	 */
	public double[] getNumerator() {
    	return mB;
	}

	/**
	 * Get the denominator (feedback) filter coefficients of this Filter instance
	 *
	 * @return the denominator filter coefficients
	 */
	public double[] getDenominator() {
		return mA;
	}

	/**
	 * Returns an All-pole IIR filter according to the design parameters
	 *
	 * @param Fc the cutoff frequency, as a fraction of the sample rate (0.0-0.5)
	 * @param passes the number of filter passes that will be used
	 * @param filterType the type of filter ({@code ALLPOLE_BUTTERWORTH},
	 * 					 {@code ALLPOLE_CRITICALLY_DAMPED}, or {@code ALLPOLE_BESSEL})
	 * @param highPass is this filter a high pass filter?
	 */
	public static Filter allPole(double Fc, int passes, int filterType, boolean highPass) {
		double[] b = new double[3];
		double[] a = new double[3];
		int n = passes;
		double c, g, p;
		switch (filterType) {
			case ALLPOLE_BUTTERWORTH:
				c = Math.pow((Math.pow(2., 1./(double)n) - 1), -0.25);
				g = 1.;
				p = Math.sqrt(2.);
				break;
			case ALLPOLE_CRITICALLY_DAMPED:
				c = Math.pow((Math.pow(2., 1./(2.*(double)n)) - 1), -0.5);
				g = 1.;
				p = 2.;
				break;
			case ALLPOLE_BESSEL:
				c = Math.pow((Math.pow((Math.pow(2., 1./(double)n) - 0.75), 0.5) - 0.5), -0.5)/Math.sqrt(3.);
				g = 3.;
				p = 3.;
				break;
			default:
				c = Math.pow((Math.pow(2., 1 / n) - 1), -0.25);
				g = 1.;
				p = Math.sqrt(2.);
		}

		if(highPass) c = 1./c;

		double fc = c*Fc;

		// Check stability
		if (!(fc > 0. && fc < 0.25))
			LOG.info("Filter unstable for Fc = " + Fc);

		if(highPass) fc = 0.5 - fc;

		double w0 = Math.tan(pi*fc);

		double K1 = p*w0;
		double K2 = g*w0*w0;

		b[0] = K2/(1 + K1 + K2);
		b[1] = 2*b[0];
		b[2] = b[0];
		a[0] = 1;
		a[1] = -2*b[0]*(1/K2 - 1);
		a[2] = -1 + (b[0] + b[1] + b[2] - a[1]);

		if(highPass) {
			a[1] = -a[1];
			b[1] = -b[1];
		}

//		System.out.println("B = " + Arrays.toString(b));
//		System.out.println("A = " + Arrays.toString(a));

		return new Filter(b, a);
	}

	/**
	 * Returns the coefficients of an all-pole IIR filter with these parameters
	 *
	 * @param fc the cutoff frequency, as a fraction of the sample rate (0.0-0.5)
	 * @param NP the number of poles of the filter
	 * @param pr the percentage of ripple in in the passband
	 * @param highPass is this filter a high pass filter?
	 */
	public static Filter chebyshev(double fc, int NP, double pr, boolean highPass) {
		if(NP < 2) throw new IllegalArgumentException("Filter cannot have less than 2 poles!");
		double[] b = new double[3];
		double[] a = new double[3];
		double[] B = new double[NP + 3];
		double[] A = new double[NP + 3];
		B[2] = 1;
		A[2] = 1;
		for(int p = 1; p <= NP/2; p++) {

			chebyshev(b, a, fc, pr, NP, highPass, p);

			double[] TB = Arrays.copyOf(B, B.length);
			double[] TA = Arrays.copyOf(A, A.length);

			for(int i = 2; i < B.length; i++) {
				B[i] = b[0]*TB[i] + b[1]*TB[i-1] + b[2]*TB[i-2];
				A[i] = a[0]*TA[i] - a[1]*TA[i-1] - a[2]*TA[i-2];
			}
		}

		//A[2] = 0;
		for(int i = 0; i < B.length-2; i++) {
			B[i] = B[i+2];
			A[i] = A[i+2];
		}

		double SB = 0.0;
		double SA = 0.0;
		for(int i = 0; i < B.length-2; i++) {
			if(highPass) {
				SB += B[i]*Math.pow(-1, i);
				SA += A[i]*Math.pow(-1, i);
			} else {
				SB += B[i];
				SA += A[i];
			}
		}

		double gain = SB/SA;
		for(int i = 0; i < B.length-2; i++) {
			B[i] = B[i]/gain;
		}

//		System.out.println("B = " + Arrays.toString(B));
//		System.out.println("A = " + Arrays.toString(A));

		return new Filter(Arrays.copyOf(B, B.length-2), Arrays.copyOf(A, A.length-2));
	}

	// Helper function for chebyshev
	private static void chebyshev(double[] b, double[] a, double fc, double pr, int NP, boolean highPass, int p) {
        double rp = -Math.cos(pi/(NP*2) + (p-1)*pi/NP);
        double ip = Math.sin(pi/(NP*2) + (p-1)*pi/NP);

        if(pr != 0) {
        	double es = Math.sqrt(Math.pow(100/(100 - pr), 2) - 1.);
        	double vx = (1./NP)*Math.log((1./es) + Math.sqrt(1./(es*es) + 1.));
			double kx = (1./NP)*Math.log((1./es) + Math.sqrt(1./(es*es) - 1.));
			kx = (Math.exp(kx) + Math.exp(-kx))/2;
			rp *= ((Math.exp(vx) - Math.exp(-vx))/2)/kx;
			rp *= ((Math.exp(vx) + Math.exp(-vx))/2)/kx;
		}

        double T = 2*Math.tan(0.5);
        double w = 2*pi*fc;
        double M = rp*rp + ip*ip;
        double D = 4 - 4*rp*T + (M*T*T);
        double X0 = T*T/D;
        double X1 = 2*T*T/D;
        double X2 = T*T/D;
        double Y1 = (8 - 2*M*T*T)/D;
        double Y2 = (-4 - 4*rp*T - M*T*T)/D;

        double K = Math.sin(0.5 - w/2)/Math.sin(0.5 + (w/2));
        if(highPass) K = -Math.cos(w/2 + 0.5)/Math.cos(w/2 - 0.5);
		D = 1.0 + Y1*K - Y2*K*K;
        b[0] = (X0 - X1*K + X2*(K*K))/D;
        b[1] = (-2*X0*K + X1 + X1*K*K - 2*X2*K)/D;
        b[2] = (X0*(K*K) - X1*K + X2)/D;
        a[0] = 1;
        a[1] = (2*K + Y1 + Y1*K*K - 2*Y2*K)/D;
        a[2] = (-(K*K) - Y1*K + Y2)/D;

        if(highPass) {
			b[1] = -b[1];
            a[1] = -a[1];
        }
    }

    public static Filter biquad(double Fc, double Q, double dBgain, int filterType) {
		double A = Math.pow(10, dBgain/40);
		double w0 = 2*pi*Fc;
		double c0 = Math.cos(w0);
		double s0 = Math.sin(w0);
		double alpha = s0/(2*Q);
		double sqrtA2alpha = 2*Math.sqrt(A)*alpha;

		double[] b = new double[3];
		double[] a = new double[3];
		switch(filterType) {
			case BIQUAD_LPF:
				b[0] = (1 - c0)/2;
				b[1] = 1 - c0;
				b[2] = b[0];
				a[0] = 1 + alpha;
				a[1] = -2*c0;
				a[2] = 1 - alpha;
				break;
			case BIQUAD_HPF:
				b[0] = (1 - c0)/2;
				b[1] = -(1 - c0);
				b[2] = b[0];
				a[0] = 1 + alpha;
				a[1] = -2*c0;
				a[2] = 1 - alpha;
				break;
			case BIQUAD_BPF:
				b[0] = Q*alpha;
				b[1] = 0;
				b[2] = -Q*alpha;
				a[0] = 1 + alpha;
				a[1] = -2*c0;
				a[2] = 1 - alpha;
				break;
			case BIQUAD_NOTCH:
				b[0] = 1;
				b[1] = -2*c0;
				b[2] = 1;
				a[0] = 1 + alpha;
				a[1] = -2*c0;
				a[2] = 1 - alpha;
				break;
			case BIQUAD_APF:
				b[0] = 1 - alpha;
				b[1] = -2*c0;
				b[2] = 1 + alpha;
				a[0] = 1 + alpha;
				a[1] = -2*c0;
				a[2] = 1 - alpha;
				break;
			case BIQUAD_PEQ:
				b[0] = 1 + alpha*A;
				b[1] = -2*c0;
				b[2] = 1 - alpha*A;
				a[0] = 1 + alpha/A;
				a[1] = -2*c0;
				a[2] = 1 - alpha/A;
				break;
			case BIQUAD_LSH:
				b[0] =   A*((A + 1) - (A - 1)*c0 + sqrtA2alpha);
				b[1] = 2*A*((A - 1) - (A + 1)*c0              );
				b[2] =   A*((A + 1) - (A - 1)*c0 - sqrtA2alpha);
				a[0] =     ((A + 1) + (A - 1)*c0 + sqrtA2alpha);
				a[1] =  -2*((A - 1) + (A + 1)*c0              );
				a[2] =     ((A + 1) + (A - 1)*c0 - sqrtA2alpha);
				break;
			case BIQUAD_HSH:
				b[0] =    A*((A + 1) + (A - 1)*c0 + sqrtA2alpha);
				b[1] = -2*A*((A - 1) + (A + 1)*c0              );
				b[2] =    A*((A + 1) + (A - 1)*c0 - sqrtA2alpha);
				a[0] =      ((A + 1) - (A - 1)*c0 + sqrtA2alpha);
				a[1] =    2*((A - 1) - (A + 1)*c0              );
				a[2] =      ((A + 1) - (A - 1)*c0 - sqrtA2alpha);
				break;
			default:
				break;
		}

		b[0] /= a[0];
		b[1] /= a[0];
		b[2] /= a[0];
		a[1] /= a[0];
		a[2] /= a[0];
		a[0] = 1.0;

		return new Filter(b, a);
	}

	/**
     * Filter a signal/data series
     *
     * @param x the signal or data series to filtered
     *
     * @return the filtered data
     */
    public float[] filter(float[] x) {
        return filter(mB, mA, x);
    }

    /**
	 * Filter a signal/data buffer using the supplied filter coefficients
	 *
	 * @param b the numerator filter coefficients
	 * @param a the denominator filter coefficients
	 * @param x the signal or data series to be filtered
	 *
	 * @return the filtered data
	 */
	public static float[] filter(float[] b, float[] a, float[] x) {
		if(a.length < 1 || b.length < 1)
			throw new IllegalArgumentException("Filter coefficients cannot be empty");
		if(a[0] != 1) {
			for(int i = 0; i < b.length; i++)
				b[i] /= a[0];
			for(int i = 1; i < a.length; i++)
				a[i] /= a[0];
			a[0] = 1.0f;
		}
		float[] y = new float[x.length];
		for(int n = 0; n < x.length; n++) {
			for (int k = 0; k < b.length; k++)
				if(k <= n) y[n] += b[k] * x[n - k];
			for (int k = 1; k < a.length; k++)
				if(k <= n) y[n] -= a[k] * y[n - k];
		}
		return y;
	}

	/**
	 * Filter a signal/data buffer using the supplied filter coefficients
	 *
	 * @param b the numerator filter coefficients
	 * @param a the denominator filter coefficients
	 * @param x the signal or data series to be filtered
	 *
	 * @return the filtered data
	 */
	public static float[] filter(float[] b, double[] a, double[] x) {
		if(a.length < 1 || b.length < 1)
			throw new IllegalArgumentException("Filter coefficients cannot be empty");
		if(a[0] != 1) {
			for(int i = 0; i < b.length; i++)
				b[i] /= a[0];
			for(int i = 1; i < a.length; i++)
				a[i] /= a[0];
			a[0] = 1.0f;
		}
		float[] y = new float[x.length];
		for(int n = 0; n < x.length; n++) {
			for (int k = 0; k < b.length; k++)
				if(k <= n) y[n] += b[k] * x[n - k];
			for (int k = 1; k < a.length; k++)
				if(k <= n) y[n] -= a[k] * y[n - k];
		}
		return y;
	}

    /**
     * Filter a signal/data buffer using the supplied filter coefficients
     *
     * @param b the numerator filter coefficients
     * @param a the denominator filter coefficients
     * @param x the signal or data series to be filtered
     *
     * @return the filtered data
     */
    public static float[] filter(double[] b, double[] a, float[] x) {
		if(a.length < 1 || b.length < 1)
			throw new IllegalArgumentException("Filter coefficients cannot be empty");
		if(a[0] != 1) {
			for(int i = 0; i < b.length; i++)
				b[i] /= a[0];
			for(int i = 1; i < a.length; i++)
				a[i] /= a[0];
			a[0] = 1.0;
		}
		float[] y = new float[x.length];
		for(int n = 0; n < x.length; n++) {
			for (int k = 0; k < b.length; k++)
				if(k <= n) y[n] += b[k] * x[n - k];
			for (int k = 1; k < a.length; k++)
				if(k <= n) y[n] -= a[k] * y[n - k];
		}
		return y;
    }

    /**
     * Filter a signal/data buffer using the supplied filter coefficients
     *
     * @param b the numerator filter coefficients
     * @param a the denominator filter coefficients
     * @param x the signal or data series to be filtered
     *
     * @return the filtered data
     */
    public static double[] filter(double[] b, double[] a, double[] x) {
        if(a.length < 1 || b.length < 1)
            throw new IllegalArgumentException("Filter coefficients cannot be empty");
        if(a[0] != 1) {
        	for(int i = 0; i < b.length; i++)
        		b[i] /= a[0];
			for(int i = 1; i < a.length; i++)
				a[i] /= a[0];
			a[0] = 1.0;
		}
        double[] y = new double[x.length];
        for(int n = 0; n < x.length; n++) {
            for (int k = 0; k < b.length; k++)
                if(k <= n) y[n] += b[k] * x[n - k];
            for (int k = 1; k < a.length; k++)
                if(k <= n) y[n] -= a[k] * y[n - k];
        }
        return y;
    }

	/**
	 * Apply an A-Weighting Filter to a signal/data series
	 *
	 * @param x the signal or data series to be filtered
	 *
	 * @return the filtered data
	 */
	public static float[] aWeighting(float[] x) {
		double[] a = {1.0, -4.0195761811158341, 6.189406442920701, -4.4531989035441244,
				1.4208429496218802,	-0.1418254738303048, 0.0043511772334950813};
		double[] b = {0.25574112520425751, -0.51148225040851258, -0.25574112520426606,
				1.022964500817038, -0.25574112520426173, -0.51148225040851303, 0.25574112520425674};
		return Filter.filter(b, a, x);
	}

	/**
	 * Apply an A-Weighting Filter to a signal/data series
	 *
	 * @param x the signal or data series to be filtered
	 *
	 * @return the filtered data
	 */
	public static double[] aWeighting(double[] x) {
		double[] a = {1.0, -4.0195761811158341, 6.189406442920701, -4.4531989035441244,
				1.4208429496218802,	-0.1418254738303048, 0.0043511772334950813};
		double[] b = {0.25574112520425751, -0.51148225040851258, -0.25574112520426606,
				1.022964500817038, -0.25574112520426173, -0.51148225040851303, 0.25574112520425674};
		return Filter.filter(b, a, x);
	}

	/**
	 * Apply a k-Weighting filter to a signal/data series
	 *
	 * @param x the signal or data series to be filtered
	 * @param fs the sample rate of the signal
	 *
	 * @return the filtered data
	 */
	public static float[] kWeighting(float[] x, int fs) {
		// Calculate coefficients from sample rate
		// First Stage Shelving Coefficients
		double VH = 1.584864701130855, VB = 1.258720930232562, VL = 1.0;
		double Q = 0.7071752369554196, fc = 1681.974450955533;
		double omega = Math.tan(Math.PI*fc/fs);
		double[] a1 = new double[3];
		double[] b1 = new double[3];
		a1[0] = (omega*omega + omega/Q + 1);
		a1[1] = 2*(omega*omega - 1)/a1[0];
		a1[2] = (omega*omega - omega/Q + 1)/a1[0];
		b1[0] = (VL*omega*omega + VB*omega/Q + VH)/a1[0];
		b1[1] = 2*(VL*omega*omega - VH)/a1[0];
		b1[2] = (VL*omega*omega - VB*omega/Q + VH)/a1[0];
		a1[0] = 1.0;
		//Second Stage Highpass Coefficients
		Q = 0.5003270373238773;
		fc = 38.13547087602444;
		omega = Math.tan(Math.PI*fc/fs);
		double[] a2 = new double[3];
		double[] b2 = {1, -2, 1};
		a2[0] = omega*omega + omega/Q + 1;
		a2[1] = 2*(omega*omega - 1)/a2[0];
		a2[2] = (omega*omega - omega/Q + 1)/a2[0];
		a2[0] = 1.0;
		// Filter
		return Filter.filter(b2, a2, Filter.filter(b1, a1, x));
	}

    /**
     * Apply a k-Weighting filter to a signal/data series
     *
     * @param x the signal or data series to be filtered
	 * @param fs the sample rate of the signal
     *
     * @return the filtered data
     */
    public static double[] kWeighting(double[] x, int fs) {
    	// Calculate coefficients from sample rate
		// First Stage Shelving Coefficients
    	double VH = 1.584864701130855, VB = 1.258720930232562, VL = 1.0;
		double Q = 0.7071752369554196, fc = 1681.974450955533;
    	double omega = Math.tan(Math.PI*fc/fs);
        double[] a1 = new double[3];
        double[] b1 = new double[3];
		a1[0] = (omega*omega + omega/Q + 1);
		a1[1] = 2*(omega*omega - 1)/a1[0];
		a1[2] = (omega*omega - omega/Q + 1)/a1[0];
        b1[0] = (VL*omega*omega + VB*omega/Q + VH)/a1[0];
        b1[1] = 2*(VL*omega*omega - VH)/a1[0];
        b1[2] = (VL*omega*omega - VB*omega/Q + VH)/a1[0];
        a1[0] = 1.0;
        //Second Stage Highpass Coefficients
		Q = 0.5003270373238773;
		fc = 38.13547087602444;
		omega = Math.tan(Math.PI*fc/fs);
		double[] a2 = new double[3];
        double[] b2 = {1, -2, 1};
		a2[0] = omega*omega + omega/Q + 1;
		a2[1] = 2*(omega*omega - 1)/a2[0];
		a2[2] = (omega*omega - omega/Q + 1)/a2[0];
		a2[0] = 1.0;
		// Filter
        return Filter.filter(b2, a2, Filter.filter(b1, a1, x));
    }

    /**
     * Apply a Pre-Emphasis Filter to a signal/data series
     *
     * @param x the signal or data series to be filtered
     *
     * @return the filtered data
     */
    public static float[] preEmphasis(float[] x) {
        double[] a = {1.0, 0.63};
        double[] b = {1.0};
        return Filter.filter(b, a, x);
    }

    /**
     * Apply a Pre-Emphasis Filter to a signal/data series
     *
     * @param x the signal or data series to be filtered
     *
     * @return the filtered data
     */
    public static double[] preEmphasis(double[] x) {
        double[] a = {1.0, 0.63};
        double[] b = {1.0};
        return Filter.filter(b, a, x);
    }

    /**
     * Apply a Simple Moving Average Filter to a signal/data series
     *
     * @param x the signal or data series to be filtered
     * @param windowSize the size of the moving average window
     *
     * @return the filtered data
     */
    public static float[] SMA(float[] x, int windowSize) {
        double[] b = new double[windowSize];
        for(int i = 0; i < windowSize; i++)
            b[i] = 1.0/windowSize;
        double[] a = new double[1];
        a[0] = 1.0;
        return Filter.filter(b, a, x);
    }

    /**
     * Apply a Simple Moving Average Filter to a signal/data series
     *
     * @param x the signal or data series to be filtered
     * @param windowSize the size of the moving average window
     *
     * @return the filtered data
     */
    public static double[] SMA(double[] x, int windowSize) {
        double[] b = new double[windowSize];
        for(int i = 0; i < windowSize; i++)
            b[i] = 1.0/windowSize;
        double[] a = new double[1];
        a[0] = 1.0;
        return Filter.filter(b, a, x);
    }

	/**
	 * Apply an Exponential Moving Average Filter to a signal/data series
	 *
	 * @param x the signal or data series to be filtered
	 * @param windowSize the size of the moving average window
	 *
	 * @return the filtered data
	 */
	public static float[] EMA(float[] x, int windowSize) {
		double alpha = (windowSize - 1)/(windowSize + 1);
		double[] a = new double[2];
		a[0] = 1.0;
		a[1] = alpha;
		double[] b = new double[1];
		b[0] = 1.0 - alpha;
		return Filter.filter(b, a, x);
	}

	/**
	 * Apply an Exponential Moving Average Filter to a signal/data series
	 *
	 * @param x the signal or data series to be filtered
	 * @param windowSize the size of the moving average window
	 *
	 * @return the filtered data
	 */
	public static double[] EMA(double[] x, int windowSize) {
		double alpha = (windowSize - 1)/(windowSize + 1);
		double[] a = new double[2];
		a[0] = 1.0;
		a[1] = alpha;
		double[] b = new double[1];
		b[0] = 1.0 - alpha;
		return Filter.filter(b, a, x);
	}
}
