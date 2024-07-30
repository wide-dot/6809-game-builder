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

/**
 *  Class for windowing sample buffers
 *  <p>
 *      Arrays of both double and float are supported. Hamming, Hann, Blackman, Flat-top, Gaussian,
 *      and Kaiser windows are available. All windows are meant to be used for spectral analysis
 *      and are therefore periodic (DFT-even).
 *  </p>
 *
 * @author Marco Martinez
 * @see funkatronics.code.tactilewaves.dsp.WaveFrame
 */
public class Window {

    public static final int WINDOW_RECTANGULAR= -1;
	public static final int WINDOW_HANN = 0;
    public static final int WINDOW_HAMMING = 1;
    public static final int WINDOW_BLACKMAN = 2;
	public static final int WINDOW_FLATTOP = 3;
    public static final int WINDOW_GAUSSIAN = 4;
	public static final int WINDOW_KAISER = 5;

    private int mWindowType;

    /**
     * Construct a new {@code Window} instance with the specified window type.
     *
     * @param windowType the window type to use. Valid window types are {@code WINDOW_HANN},
     *                  {@code WINDOW_HAMMING}, {@code WINDOW_BLACKMAN}, {@code WINDOW_FLATTOP},
	 *                  {@code WINDOW_GAUSSIAN}, or {@code WINDOW_KAISER}.
     */
    public Window(int windowType) {
        this.mWindowType = windowType;
    }

    /**
     * Construct a new {@code Window} instance with a rectangular window
     */
    public Window() {
        this.mWindowType = WINDOW_RECTANGULAR;
    }

    /**
     * Get the window type associated with this {@code Window} instance.
     *
     * @return the window type. Valid window types are {@code WINDOW_HANN},
	 * 		   {@code WINDOW_HAMMING}, {@code WINDOW_BLACKMAN}, {@code WINDOW_FLATTOP},
	 *         {@code WINDOW_GAUSSIAN}, or {@code WINDOW_KAISER}.
     */
    public int getWindowType() {
        return mWindowType;
    }

    /**
     * Set the window type of this {@code Window} instance.
     *
     * @param windowType the window type to use. Valid window types are {@code WINDOW_HANN},
     *                  {@code WINDOW_HAMMING}, {@code WINDOW_BLACKMAN}, {@code WINDOW_FLATTOP},
	 *         			{@code WINDOW_GAUSSIAN}, or {@code WINDOW_KAISER}.
     */
    public void setWindowType(int windowType) {
        this.mWindowType = windowType;
    }

	/**
	 * Sets the window function to a Hann window for this {@code Window} instance.
	 */
	public void setWindowHanning() {
		mWindowType = WINDOW_HANN;
	}

    /**
     * Sets the window function to a Hamming window for this {@code Window} instance.
     */
    public void setWindowHamming() {
        mWindowType = WINDOW_HAMMING;
    }

	/**
	 * Sets the window function to a Blackman window for this {@code Window} instance.
	 */
	public void setWindowBlackman() {
		mWindowType = WINDOW_BLACKMAN;
	}

	/**
	 * Sets the window function to a Flat-top window for this {@code Window} instance.
	 */
	public void setWindowFlattop() {
		mWindowType = WINDOW_FLATTOP;
	}

    /**
     * Sets the window function to a Gaussian window for this {@code Window} instance.
     */
    public void setWindowGaussian() {
        mWindowType = WINDOW_GAUSSIAN;
    }

	/**
	 * Sets the window function to a Kaiser window for this {@code Window} instance.
	 */
	public void setWindowKaiser() {
		mWindowType = WINDOW_KAISER;
	}

    /**
     * Window a signal using the window function saved to this {@code Window} instance.
     *
     * @param x the signal array to be windowed
     */
    public float[] window(float[] x) {
        switch(mWindowType) {
			case WINDOW_HANN:
				return hann(x);
			case WINDOW_HAMMING:
				return hamming(x);
			case WINDOW_BLACKMAN:
				return blackman(x);
			case WINDOW_FLATTOP:
				return flattop(x);
			case WINDOW_GAUSSIAN:
				return gaussian(x);
			case WINDOW_KAISER:
				return kaiser(x);
			default:
				return Arrays.copyOf(x, x.length);
        }
    }

    /**
     * Window a signal using the window function saved to this {@code Window} instance.
     *
     * @param x the signal array to be windowed
     */
    public double[] window(double[] x) {
		switch(mWindowType) {
			case WINDOW_HANN:
				return hann(x);
			case WINDOW_HAMMING:
				return hamming(x);
			case WINDOW_BLACKMAN:
				return blackman(x);
			case WINDOW_FLATTOP:
				return flattop(x);
			case WINDOW_GAUSSIAN:
				return gaussian(x);
			case WINDOW_KAISER:
				return kaiser(x);
			default:
				return Arrays.copyOf(x, x.length);
		}
    }

    /**
     * Windows a signal using a standard Hann window.
     *
     * @param  x the signal array to be windowed
	 *
	 * @return the windowed signal
     */
    public static float[] hann(float[] x) {
		int N = x.length;
		float[] y = new float[N];
		for (int i = 0; i < N; i++) {
			double temp = Math.sin(Math.PI*i/N);
			y[i] = x[i]*(float)(temp*temp);
		}
		return y;
    }

    /**
     * Windows a signal using a standard Hann window.
     *
     * @param  x the signal array to be windowed
	 *
	 * @return the windowed signal
     */
    public static double[] hann(double[] x) {
        int N = x.length;
		double[] y = new double[N];
        for (int i = 0; i < N; i++) {
            double temp = Math.sin(Math.PI*i/N);
			y[i] = x[i]*(float)(temp*temp);
        }
		return y;
    }

	/**
	 * Windows a signal using a standard Hamming window.
	 *
	 * @param  x the signal array to be windowed
	 *
	 * @return the windowed signal
	 */
	public static float[] hamming(float[] x) {
		int N = x.length ;
		float[] y = new float[N];
		for (int i = 0; i < N; i++) {
			y[i] = x[i]*(float)(0.54 - 0.46*Math.cos((2*Math.PI*i)/N));
		}
		return y;
	}

	/**
	 * Windows a signal using a standard Hamming window.
	 *
	 * @param  x the signal array to be windowed
	 *
	 * @return the windowed signal
	 */
	public static double[] hamming(double[] x) {
		int N = x.length ;
		double[] y = new double[N];
		for (int i = 0; i < N; i++) {
			y[i] = x[i]*(0.54 - 0.46*Math.cos((2*Math.PI*i)/N));
		}
		return y;
	}

    /**
     * Windows a signal using a standard Blackman window.
     *
     * @param  x the signal array to be windowed
	 *
	 * @return the windowed signal
     */
    public static float[] blackman(float[] x) {
        int N = x.length;
		float[] y = new float[N];
        for (int i = 0; i < N; i++) {
			y[i] = x[i]*(float)(0.42 - 0.5*Math.cos((2*Math.PI*i)/N)
					+ 0.08*Math.cos((4*Math.PI*i)/N));
        }
		return y;
    }

    /**
     * Windows a signal using a standard Blackman window.
     *
     * @param  x the signal array to be windowed
	 *
	 * @return the windowed signal
     */
    public static double[] blackman(double[] x) {
		int N = x.length;
		double[] y = new double[N];
		for (int i = 0; i < N; i++) {
			y[i] = x[i]*(0.42 - 0.5*Math.cos((2*Math.PI*i)/N)
							 + 0.08*Math.cos((4*Math.PI*i)/N));
		}
		return y;
    }

	/**
	 * Windows a signal using a standard Flat-top window.
	 *
	 * @param  x the signal array to be windowed
	 *
	 * @return the windowed signal
	 */
	public static float[] flattop(float[] x) {
		int N = x.length;
		float[] y = new float[N];
		for (int i = 0; i < N; i++) {
			y[i] = x[i]*(float)(0.21557895 - 0.41663158*Math.cos((2*Math.PI*i)/N)
					+ 0.277263158*Math.cos((4*Math.PI*i)/N)
					- 0.083578947*Math.cos((6*Math.PI*i)/N)
					+ 0.006947368*Math.cos((8*Math.PI*i)/N));
		}
		return y;
	}

	/**
	 * Windows a signal using a standard Flat-top window.
	 *
	 * @param  x the signal array to be windowed
	 *
	 * @return the windowed signal
	 */
	public static double[] flattop(double[] x) {
		int N = x.length;
		double[] y = new double[N];
		for (int i = 0; i < N; i++) {
			y[i] = x[i]*(0.21557895 - 0.41663158*Math.cos((2*Math.PI*i)/N)
						+ 0.277263158*Math.cos((4*Math.PI*i)/N)
						- 0.083578947*Math.cos((6*Math.PI*i)/N)
						+ 0.006947368*Math.cos((8*Math.PI*i)/N));
		}
		return y;
	}

    /**
     * Windows a signal using a standard Gaussian window.
     *
     * @param  x the signal array to be windowed
	 *
	 * @return the windowed signal
     */
    public static float[] gaussian(float[] x) {
        return gaussian(x, 2.5);
    }

    /**
     * Windows a signal using a standard Gaussian window.
     *
     * @param  x the signal array to be windowed
	 *
	 * @return the windowed signal
     */
    public static double[] gaussian(double[] x) {
        return gaussian(x, 2.5);
    }

    /**
     * Windows a signal using a Gaussian window with alpha to adjust the window
     * width. Alpha is proportional to the standard deviation of the resulting window {@code sigma =
     * (N-1)/2*alpha}.
     *
     * @param x the signal array to be windowed
     * @param alpha alpha value to adjust window width
	 *
	 * @return the windowed signal
     */
    public static float[] gaussian(float[] x, double alpha) {
		int N = x.length;
		float[] y = new float[N];
		for (int i = 0; i < N; i++) {
			double n = i - N/2;
			y[i] = x[i]*(float)Math.exp(-0.5*Math.pow(alpha*n/(N/2.0), 2));
		}
		return y;
    }

    /**
     * Windows a signal using a Gaussian window with alpha to adjust the window
     * width. Alpha is proportional to the standard deviation of the resulting window {@code sigma =
     * (N-1)/2*alpha}.
     *
     * @param x the signal array to be windowed
     * @param alpha alpha value to adjust window width
	 *
	 * @return the windowed signal
     */
    public static double[] gaussian(double[] x, double alpha) {
        int N = x.length;
		double[] y = new double[N];
        for (int i = 0; i < N; i++) {
            double n = i - N/2;
			y[i] = x[i]*Math.exp(-0.5*Math.pow(alpha*n/(N/2.0), 2));
        }
		return y;
    }

	/**
	 * Windows a signal using a standard Kaiser window.
	 *
	 * @param  x the signal array to be windowed
	 *
	 * @return the windowed signal
	 */
	public static float[] kaiser(float[] x) {
		return kaiser(x, 3.0);
	}

	/**
	 * Windows a signal using a standard Kaiser window.
	 *
	 * @param  x the signal array to be windowed
	 *
	 * @return the windowed signal
	 */
	public static double[] kaiser(double[] x) {
		return kaiser(x, 3.0);
	}

	/**
	 * Windows a signal using a Kaiser window with alpha to adjust the window width.
	 *
	 * @param x the signal array to be windowed
	 * @param alpha alpha value to adjust window width
	 *
	 * @return the windowed signal
	 */
	public static float[] kaiser(float[] x, double alpha) {
		int N = x.length;
		int ND2 = N/2;
		float[] y = new float[N];
		for (int i = 0; i < N; i++) {
			y[i] = x[i]*(float)(modBesselFirstKindOrder0(Math.PI*alpha*Math.sqrt(1 - ((i-ND2)/ND2)*((i-ND2)/ND2)))
					/modBesselFirstKindOrder0(Math.PI*alpha));
		}
		return y;
	}

    /**
     * Windows a signal using a Kaiser window with alpha to adjust the window width.
     *
     * @param x the signal array to be windowed
     * @param alpha alpha value to adjust window width
	 *
	 * @return the windowed signal
     */
    public static double[] kaiser(double[] x, double alpha) {
		int N = x.length;
        double ND2 = N/2.0;
        double[] y = new double[N];
        for (int i = 0; i < N; i++) {
            y[i] = x[i]*(modBesselFirstKindOrder0(Math.PI*alpha*Math.sqrt(1 - ((i-ND2)/ND2)*((i-ND2)/ND2)))
						 /modBesselFirstKindOrder0(Math.PI*alpha));
        }
        return y;
    }

    // Returns the zeroth order modifed Bessel function of the first kind, evaluated at z
    private static double modBesselFirstKindOrder0(double z) {
    	double pi = Math.PI;
    	int n = 20;
    	double sum = 0.0;
    	for(int k = 1; k < n; k++)
    		sum += Math.exp(z*Math.cos(k*pi/n));
    	return (1.0/n)*(Math.exp(z*Math.cos(0))/2 + sum + Math.exp(z*Math.cos(pi))/2);
	}

	/**
	 * Computes the frequency response of a window function
	 *
	 * @param bins number of bins in the response
	 * @param windowType the type of window to compute the response of
	 *
	 * @return the frequency response of the window
	 */
    public static double[] getResponse(int bins, int windowType) {
		double[] w = new double[bins*2];
		Arrays.fill(w, 1.0);
    	Window window = new Window(windowType);
    	window.window(w);
    	double[] a = new double[bins+1];
    	for(int f = -bins/2; f <= bins/2; f++) {
    		double r = 0.0;
    		double i = 0.0;
    		double s = 0.0;
    		for(int j = 0; j < bins*2; j++) {
    			r += w[j]*Math.cos(2*Math.PI*f*j/(bins*2 + 1));
				i += w[j]*Math.sin(2*Math.PI*f*j/(bins*2 + 1));
				s += w[j];
			}
			a[f+bins/2] = Math.sqrt(r*r + i*i)/s;
		}
		return a;
	}

	/**
	 * Computes the frequency response of a window function
	 *
	 * @param w the window
	 *
	 * @return the frequency response of the window
	 */
	public static double[] getResponse(double[] w) {
		int bins = w.length/2;
		double[] a = new double[bins+1];
		for(int f = -bins/2; f <= bins/2; f++) {
			double r = 0.0;
			double i = 0.0;
			double s = 0.0;
			for(int j = 0; j < bins*2; j++) {
				r += w[j]*Math.cos(2*Math.PI*f*j/(bins*2 + 1));
				i += w[j]*Math.sin(2*Math.PI*f*j/(bins*2 + 1));
				s += w[j];
			}
//			r += w[0]*Math.cos(2*Math.PI*f*bins*2/(bins*2 + 1));
//			i += w[0]*Math.sin(2*Math.PI*f*bins*2/(bins*2 + 1));
//			s += w[0];
			a[f+bins/2] = Math.sqrt(r*r + i*i)/s;
		}
		return a;
	}
}
