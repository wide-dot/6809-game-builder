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

package funkatronics.code.tactilewaves.io;

/**
 *  {@code WaveFormat} Class for specifying various audio format parameters of some audio data
 *  <p>
 *      Currently, only PCM (Linear Quantization, Uncompressed) Encoding is supported.
 *  </p>
 *
 */

public class WaveFormat{

    public static final int NOT_SPECIFIED = -1;
    public static final int ENCODING_PCM_SIGNED = 0;
    public static final int ENCODING_PCM_UNSIGNED = 1;

    // The encoding method used by this format
    private int mEncoding;

    // True if the audio data is stored in big-endian order, false if little-endian
    private boolean mBigEndian;

    // The number of samples per second of the underlying audio
    private int mSampleRate;

    // The number of bits used to represent 1 sample of a single channel of audio
    private int mBitDepth;

    // The number of separate channels in the underlying audio
    private int mNumChannels;

    // The number of bytes used per audio sample, including all channels
    // blockAlign = numChannels * bitDepth/8
    private int mBlockAlign;

    /**
     * Constructs a <code>WaveFormat</code> with the given parameters.
     *
     * @param encoding      the method of encoding used in the format
     * @param bigEndian     the endian-ness of the audio data (<code>false</code> = little-endian)
     * @param sampleRate    the number of samples per second
     * @param bitDepth      the number of bits per sample
     * @param channels      the number of channels in the audio stream
     */
    public WaveFormat(int encoding, Boolean bigEndian, int sampleRate, int bitDepth, int channels) {
        mEncoding = encoding;
        mBigEndian = bigEndian;
        mSampleRate = sampleRate;
        mBitDepth = bitDepth;
        mNumChannels = channels;
        mBlockAlign = channels*bitDepth/8;
    }

    /**
     * Returns a <code>WaveFormat</code> with the standard Microsoft WAVE format (Little Endian PCM)
     *
     * @param sampleRate the sample rate to use in this format
     * @param bitDepth the number of bits/sample to use in this format
     * @param channels the number of channels to use in this format
     *
     * @return a {@code WaveFormat} with the default Microsoft WAVE audio format parameters
     */
    public static WaveFormat MSWAVEFormat(int sampleRate, int bitDepth, int channels) {
        return new WaveFormat(WaveFormat.ENCODING_PCM_SIGNED, false, sampleRate, bitDepth, channels);
    }

    /**
     * Returns a <code>WaveFormat</code> with the default Android format (16 bit mono Big Endian PCM)
     *
     * @return a {@code WaveFormat} with the default Android audio format parameters
     */
    public static WaveFormat AndroidFormat() {
        return new WaveFormat(WaveFormat.ENCODING_PCM_SIGNED, true, 44100, 16, 1);
    }

    /**
     * Gets the encoding method constant for the audio with this format
     *
     * @return the encoding constant
     */
    public int getEncoding(){
        return mEncoding;
    }

    /**
     * Reports if the audio data is stored in big-endian byte order
     *
     * @return True if big-endian, False if little-endian
     */
    public boolean isBigEndian() {
        return mBigEndian;
    }

    /**
     * Gets the sample rate of the audio with this format
     *
     * @return the sample rate
     */
    public int getSampleRate(){
        return mSampleRate;
    }

    /**
     * Gets the bit depth (bits/sample) of the audio with this format
     *
     * @return the bit depth
     */
    public int getBitDepth() {
        return mBitDepth;
    }

    /**
     * Gets the number of channels of the audio with this format
     *   1 = Mono
     *   2 = Stereo
     *   3+ usually indicates some type of surround sound or custom channel configuration
     *
     * @return the number of channels
     */
    public int getChannels() {
        return mNumChannels;
    }

    /**
     * Gets the bytes used per sample of the audio with this format
     *
     * @return the bytes/sample
     */
    public int getBytesPerSample() {
        return mBlockAlign;
    }

    @Override
    public String toString(){
        String msg = "Audio Format: ";

        if(getBitDepth() == NOT_SPECIFIED) {
            msg += "Unspecified Bit Depth ";
        } else {
            msg += getBitDepth() + "BIT ";
        }

        switch(mEncoding) {
            case NOT_SPECIFIED:
                msg += "Unspecified Encoding with ";
                break;
            case ENCODING_PCM_SIGNED:
                msg += "Signed PCM (Linear Quantization) Encoding with ";
                break;
            case ENCODING_PCM_UNSIGNED:
                msg += "Unsigned PCM (Linear Quantization) Encoding with ";
                break;
        }

        if(isBigEndian()) {
            msg += "Big Endian byte order ";
        } else {
            msg += "Little Endian byte order ";
        }

        if(getSampleRate()== NOT_SPECIFIED) {
            msg += "@ unspecified sample rate ";
        } else {
            msg += "@ " + getSampleRate() + "Hz ";
        }

        if(getChannels()== NOT_SPECIFIED) {
            msg += "with an unspecified number of channels ";
        } else {
            msg += "with " + getChannels() + " channels ";
        }

        if(getBytesPerSample()== NOT_SPECIFIED) {
            msg += "resulting in an unspecified byte/sample";
        } else {
            msg += "resulting in " + getBytesPerSample() + " bytes/sample";
        }

        return msg;
    }

}
