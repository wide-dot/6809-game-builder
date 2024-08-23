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

import java.util.HashMap;

import funkatronics.code.tactilewaves.io.WaveFormat;

/**
 * Class the represents a single frame of audio.
 * <p>
 *     A {@code HashMap} is used to allow {@link WaveProcessor} objects to store any useful
 *     information about the frame - called features. This allows the processors to attach any
 *     object along with the frame to be used downstream. This is useful, for example, for storing
 *     the pitch of the frame, or its MFCCs.
 * </p>
 * <p>
 *     Loosely based on Joren Six's <a href="https://github.com/JorenSix/TarsosDSP/blob/master/src/core/be/tarsos/dsp/AudioEvent.java">AudioEvent</a>
 *     object from his <a href="http://github.com/JorenSix/TarsosDSP/">TarsosDSP</a> library.
 * </p>
 *
 * @author Marco Martinez
 *
 * @see WaveManager
 * @see WaveFormat
 */

public class WaveFrame {

    // The format of the audio frame
    private final WaveFormat mFormat;

    // The sample buffer - the audio frame itself
    private float[] mSamples;

    // The length of the frame (length of the sample buffer)
    private int mLength;

    //private List<WaveFeature> features;

    // A list (map, technically) of extracted audio features
    // such as the pitch or formant frequencies
    private HashMap<String, Object> mFeatures;

    /**
     * Construct a new {@code WaveFrame} from a {@link WaveFormat}
     *
     * @param format the {@code WaveFormat} with the format parameters for this {@code WaveFrame}
     */
    public WaveFrame(WaveFormat format){
        mFormat = format;
        mFeatures = new HashMap<>();
    }

    /**
     * Construct a new {@code WaveFrame} from a sample buffer and a {@link WaveFormat}
     *
     * @param samples the sample buffer (audio frame/buffer)
     * @param format the {@code WaveFormat} with the format parameters for this {@code WaveFrame}
     */
    public WaveFrame(float[] samples, WaveFormat format){
        this(format);
        updateFrame(samples);
    }

    /**
     * Update the sample buffer of this {@code WaveFrame}
     *
     * @param samples the new sample buffer
     */
    public void updateFrame(float[] samples) {
        mLength = samples.length;
        mSamples = samples;
    }

    /**
     * Get the sample buffer (current frame) of this {@code WaveFrame}
     *
     * @return the sample buffer
     */
    public float[] getSamples(){
        return mSamples;
    }

    /**
     * Get the sample rate of this {@code WaveFrame}
     *
     * @return the sample rate
     */
    public int getSampleRate(){
        return mFormat.getSampleRate();
    }
    
    /**
     * Get the bit depth of this {@code WaveFrame}
     *
     * @return the bit depth
     */
    public int getBitDepth(){
        return mFormat.getBitDepth();
    }

    /**
     * Get the length of this {@code WaveFrame}
     *
     * @return the length of the frame (length of the audio buffer)
     */
    public int getFrameLength(){
        return mLength;
    }

    /**
     * Add a feature to the feature set.
     *
     * @param name the name (key) of the new feature to add
     * @param feature the feature to add
     */
    public void addFeature(String name, Object feature) {
        mFeatures.put(name, feature);
    }

    /**
     * Remove a feature from the feature set.
     *
     * @param name the name (key) of the feature to remove
     */
    public void removeFeature(String name) {
        mFeatures.remove(name);
    }

    /**
     * Get a feature from the feature set from its name (key)
     *
     * @param name the name (key) of the feature to get
     *
     * @return the feature, if it exists, otherwise a null object reference
     */
    public Object getFeature(String name) {
        return mFeatures.get(name);
    }

    /**
     * Returns the Sound Pressure Level in decibels (dBSPL) of an audio buffer.
     *
     * @param buffer The buffer with audio information
     *
     * @return The dBSPL level for the buffer
     */
    private double dBSPL(final float[] buffer) {
        double value = Math.pow(totalEnergy(buffer), 0.5);
        value = value/buffer.length;
        return a2dB(value);
    }

    /**
     * Calculates the total energy of an audio buffer.
     *
     * @param buffer The audio buffer
     *
     * @return The total energy of an audio buffer
     */
    private double totalEnergy(final float[] buffer) {
        double energy = 0.0;
        for (float sample : buffer) {
            energy += sample*sample;
        }
        return energy;
    }

    /**
     * Does this {@code WaveFRame} contain silence?
     *
     * @param silenceThreshold the energy threshold, below this value is silence
     *
     * @return true if the total energy of the audio frame is below the threshold
     */
    public boolean isSilence(double silenceThreshold) {
        return dBSPL(mSamples) < silenceThreshold;
    }

    public double getDBSPL() {
        return dBSPL(mSamples);
    }

    /**
     * Converts a frequency value to an array index based on the length and sample rate of the array
     *
     * @param freq the frequency to convert to an index
     * @return the corrosponding index where this frequency is located
     */
    public int freq2Index(float freq) {
        return (int)((freq/ mFormat.getSampleRate()) * mLength);
    }

    /**
     * Converts an array index to a frequency value based on the length and sample rate of the array
     *
     * @param index the index to convert to a frequency value
     * @return the frequency corresponding to this index
     */
    public double index2Freq(int index) {
        return (index/(double) mLength) * mFormat.getSampleRate();
    }

	/**
	 * Covert a linear value to decibels (dBu)
	 *
	 * @param val the value to convert to decibels
	 *
	 * @return the resulting decibel value
	 */
	public static double a2dB(final double val) {
		return a2dB(val, 0.775);
	}

    /**
     * Covert a linear value to decibels (dB). The aRef parameter defines the resulting decibel
	 * scale, i.e. 1.0 for dBV, 0.775 for dBu, etc.
     *
     * @param val the value to convert to decibels
     * @param aRef the reference amplitude at 0.0 dB
	 *
     * @return the resulting decibel value
     */
    public static double a2dB(final double val, final double aRef) {
        return 20 * Math.log10(val/aRef);
    }
}
