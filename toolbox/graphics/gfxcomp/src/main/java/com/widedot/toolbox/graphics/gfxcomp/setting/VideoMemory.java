package com.widedot.toolbox.graphics.gfxcomp.setting;

public class VideoMemory{
    public static Integer memoryLinearBits;
    public static Integer memoryPlanarBits;
    public static Integer memoryLineBytes;
    public static Integer memoryNbPlanes;

    /**
     * Distance in bytes between the two halves of the video window.
     *
     * A machine constant, not a property of the image, and not derivable from
     * the geometry above : on TO8 the window at $A000-$DFFF is two 8 KB planes,
     * so $2000 apart. Only the planes="offset" encoding needs it — the default
     * reaches the second plane through glb_screen_location_1 and never has to
     * know how far it is.
     */
    public static Integer memoryPlaneDistance;
}
