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

package funkatronics.code.tactilewaves.dsp.utilities;

/**
 * Class to solve for the roots of polynomials using the
 * <a href="https://en.wikipedia.org/wiki/Durand%E2%80%93Kerner_method">
 *     Durand-Kerner root finding algorithm.
 * </a>
 *
 * <p>
 *     The convergence criteria of the algorithm can be adjusted to trade accuracy for performance.
 * </p>
 *
 * @author Marco Martinez
 * @see funkatronics.code.tactilewaves.dsp.toolbox.LPC
 */

public class RootSolver {

    // Do not allow instantiation
    private RootSolver() {}

    /**
     * Solve for the roots of a polynomial
     *
     * @param p the polynomial coefficients
     * @param maximizeAccuracy sets the accuracy level of the root solver. A value of true returns
     *                         more accurate results with a larger computational cost.
     *
     * @return the complex roots of the polynomial in a {@link Complex} array
     *
     * @throws SolverNotConvergedException if the root solver could not converge to a solution
     */
    public static Complex[] roots(double[] p, boolean maximizeAccuracy)
            throws SolverNotConvergedException {
        // from testing, this delta value results in more accurate root solving than MatLab's own root() function
        if(maximizeAccuracy) return DKRoots(p, 0.00000000000001, 1000);
        // from testing, this delta value gives a balance of accuracy and performance
        else return DKRoots(p, 0.0001, 100);
    }

    /**
     * Solve for the roots of a polynomial
     * @param p the polynomial coefficients
     * @param stopThreshold the convergence threshold. When the roots change by less than this value
     *                      between iterations, the algorithm stops and returns the roots. Smaller
     *                      values lead to more accurate results with a larger computational cost.
     * @param maxIterations if the iteration surpasses this value before meeting the converge
     *                      threshold, a {@link SolverNotConvergedException} is thrown.
     *
     * @return the complex roots of the polynomial in a {@link Complex} array
     *
     * @throws SolverNotConvergedException if the root solver could not converge to a solution
     */
    public static Complex[] roots(double[] p, double stopThreshold, int maxIterations)
            throws SolverNotConvergedException {
        return DKRoots(p, stopThreshold, maxIterations);
    }

    // Find the roots of the polynomial p using the Durand–Kerner root finding algorithm
    private static Complex[] DKRoots(final double[] p, double stopThreshold, int maxIterations)
            throws SolverNotConvergedException {
        Complex[] rts = new Complex[p.length-1];

        rts[0] = new Complex(-1, 0);
        for(int i = 1; i < rts.length; i++) {
            rts[i] = new Complex(-0.4, 0.9);
            rts[i] = rts[i].pow(i);
        }

        double maxDelta = 1.0;
        int iterations = 0;
        while(maxDelta >= stopThreshold) {
            maxDelta = Double.MIN_VALUE;
            for(int i = 0; i < rts.length; i++) {
                double prev = rts[i].mag();
                Complex c = rts[i];
                Complex f = evaluate(p, c);
                Complex[] denoms = new Complex[rts.length-1];
                for(int j = 1; j < rts.length; j++) {
                    int s = i+j;
                    if(s > denoms.length) s -= denoms.length + 1;
                    denoms[j-1] = new Complex(c);
                    denoms[j-1] = denoms[j-1].minus(rts[s]);
                }
                Complex denom = new Complex(denoms[0]);
                for(int j = 1; j < denoms.length; j++) {
                    denom = denom.times(denoms[j]);
                }
                Complex result = new Complex(f);
                result = result.divide(denom);
                rts[i] = rts[i].minus(result);

                double delta = Math.abs(rts[i].mag() - prev);
                if(delta > maxDelta) maxDelta = delta;
            }
            if(++iterations > maxIterations)
                throw new SolverNotConvergedException("The root solver could not converge to a " +
                        "solution for the provided polynomial");
        }

        return rts;
    }

    // Evaluate the polynomial p @ x
    private static Complex evaluate(double[] c, Complex x) {
        int N = c.length;
        Complex f = new Complex(0.0, 0.0);
        for(int i = 0; i < N; i++) {
            Complex xt =  new Complex(x);
            xt = xt.pow(N-1-i);
            xt = xt.times(c[i]);
            f = f.plus(xt);
        }
        return f;
    }
}
