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
 *  Class for creating an object that represents a complex number
 *  <p>
 *      Includes implementations of various mathematical operations with complex numbers including
 *      addition, subtraction, multiplication, division, exponentiation, etc.
 *  </p>
 *  <div>
 *      Complex numbers are of the form:
 *      <p>
 *          <em>{@code z = x + yi}</em>
 *      </p>
 *      Where x is the real part and y is the imaginary part of the complex number, and z is the
 *      complex number represented by this object
 *  </div>
 *
 * @author Marco Martinez
 */

public class Complex {

    private double mReal;
    private double mImag;

    /**
     * Construct a new Complex number object with specified Real and Imaginary parts
     *
     * @param real the Real part of the Complex number
     * @param imag the Imaginary part of the Complex number
     */
    public Complex(double real, double imag) {
        this.mReal = real;
        this.mImag = imag;
    }

    /**
     * Copy Constructor - Construct a new Complex number object that is a copy of another
     *
     * @param c the Complex number to make a copy part of
     */
    public Complex(Complex c) {
        this.mReal = c.mReal;
        this.mImag = c.mImag;
    }

    /**
     * Returns a new Complex Number wil the value 1 + 0i.
     *
     * @return A new complex number equal to 1 + 0i;
     */
    public static Complex UNITY() {
        return new Complex(1, 0);
    }

    /**
     * Returns an array of {@code Complex} number objects created from separate arrays of real and
     * imaginary numbers
     *
     * @param real the array of real numbers
     * @param imag the array of imaginary numbers
     *
     * @return an array of {@code Complex} numbers
     *
     * @throws IllegalArgumentException if the length of real != the length of imag
     */
    public static Complex[] complexArray(double[] real, double[] imag) {
        if(real.length != imag.length) throw new IllegalArgumentException("Real and Imaginary arrays must be equal length!");
        Complex[] r = new Complex[real.length];
        for(int i = 0; i < r.length; i++)
            r[i] = new Complex(real[i], imag[i]);
        return r;
    }

    /**
     * Is this complex number a Real number?
     *
     * @return true if this Complex number is Real (imaginary part == 0)
     */
    public boolean isReal() {
        return this.mImag == 0;
    }

    /**
     * Return the real part (x) of this Complex number (z)
     *
     * @return the real part of this Complex number
     */
    public double real() {
        return mReal;
    }

    /**
     * Return the imaginary part (y) of this Complex number (z)
     *
     * @return the imaginary part of this Complex number
     */
    public double imag() {
        return mImag;
    }

    /**
     * Returns the Complex Magnitude of this Complex Number
     *
     * @return the magnitude of this complex number
     *          <br> mag(z) = sqrt(x^2 + y^2)
     */
    public double mag() {
        return Math.sqrt(mReal * mReal + mImag * mImag);
    }

    /**
     * Returns the Power of this Complex Number
     *
     * @return the magnitude of this complex number
     *          <br> power(z) = x^2 + y^2
     */
    public double power() {
        return mReal * mReal + mImag * mImag;
    }

    /**
     * Returns the Argument of this Complex number
     *
     * @return the Argument of this complex number
     *          <br> arg(z) = Math.atan2(y, x)
     */
    public double arg() {
        return Math.atan2(mImag, mReal);
    }

    /**
     * Returns the complex conjugate of this Complex Number
     *
     * @return the magnitude of this complex number
     *          <br> conj(z) = x + (-1)*yi
     */
    public Complex conj() {
        return new Complex(mReal, -mImag);
    }

    /**
     * Returns the Reciprocal of this Complex Number
     *
     * @return the Reciprocal of this complex number
     *          <br> recip(z) = x/mag(z)^2 + yi/mag(z)^2
     */
    public Complex reciprocate() {
        double scale = mReal * mReal + mImag * mImag;
        return new Complex(this.mReal /scale, -this.mImag /scale);
    }

    /**
     * Returns the Complex Exponential of this Complex Number
     *
     * @return the Complex Exponential of this complex number
     *          <br> exp(z) = exp(x)*cos(y) + exp(x)*sin(y)i
     */
    public Complex exp() {
        return new Complex(Math.exp(mReal)*Math.cos(mImag), Math.exp(mReal *Math.sin(mImag)));
    }

    /**
     * Adds a Complex number to this Complex number and returns the result in a new Complex number
     *
     * @param c a Complex number to add to this Complex number
     * @return the result of the addition
     */
    public Complex plus(Complex c) {
        return new Complex(this.mReal +c.mReal, this.mImag +c.mImag);
    }

    /**
     * Adds a Real number to this Complex number and returns the result in a new Complex number
     *
     * @param r a Real number to plus to this Complex number
     * @return the result of this addition
     */
    public Complex plus(double r) {
        return new Complex(mReal +r, mImag);
    }

    /**
     * Subtracts a Complex number from this Complex number and returns the result in a new Complex
     * number
     *
     * @param c a Complex number to subtract from this Complex number
     * @return the result of the subtraction
     */
    public Complex minus(Complex c) {
        return new Complex(this.mReal -c.mReal, this.mImag -c.mImag);
    }

    /**
     * Subtracts a real number from this Complex number and returns the result in a new Complex
     * number
     *
     * @param r a Real number to subtract from this Complex number
     * @return the result of the subtraction
     */
    public Complex minus(double r) {
        return new Complex(mReal -r, mImag);
    }

    /**
     * Multiply this Complex number with another Complex number and returns the result in a new
     * Complex number
     *
     * @param c a Complex number to multiply with this Complex number
     * @return the result of the multiplication
     */
    public Complex times(Complex c) {
        return new Complex(this.mReal *c.mReal - this.mImag *c.mImag,
                this.mReal *c.mImag + this.mImag *c.mReal);
    }

    /**
     * Multiply this Complex number with a Real number and returns the result in a new Complex
     * number
     *
     * @param r a Real number to multiply with this Complex number
     * @return the result of the multiplication
     */
    public Complex times(double r) {
        return new Complex(mReal *r, mImag *r);
    }

    /**
     * Multiply this Complex number with another Complex number and returns the result in a new
     * Complex number
     *
     * @param c a Complex number to multiply with this Complex number
     * @return the result of the multiplication
     */
    public Complex divide(Complex c) {
        return this.times(c.reciprocate());
    }

    /**
     * Multiply this Complex number with another Complex number and returns the result in a new
     * Complex number
     *
     * @param r a real number to divide this Complex number with
     * @return the result of the multiplication
     */
    public Complex divide(double r) {
        return this.times(1/r);
    }

    /**
     * Raise this complex number to a power of e and return the result in a new Complex number
     *
     * @param e the power to raise this Complex number to
     * @return the result of z^e
     */
    public Complex pow(int e) {
        if(e == 0) {
            return new Complex(1, 0);
        } else if(e == 1)
            return new Complex(mReal, mImag);

        Complex temp = new Complex(this);
        for(int i = 2; i <= e; i++) {
            temp = this.times(temp);
        }
        return temp;
    }

    @Override
    public boolean equals(Object x) {
        if (x == null) return false;
        if (this.getClass() != x.getClass()) return false;
        Complex that = (Complex) x;
        return (this.mReal == that.mReal) && (this.mImag == that.mImag);
    }

    @Override
    public String toString() {
        if (mImag == 0) return mReal + "";
        if (mReal == 0) return mImag + "i";
        if (mImag <  0) return mReal + " - " + (-mImag) + "i";
        return mReal + " + " + mImag + "i";
    }

}
