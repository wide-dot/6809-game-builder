package com.widedot.toolbox.debug.ui;

import org.lwjgl.opengl.GL12;

import static org.lwjgl.opengl.GL11.*;
import static org.lwjgl.opengl.GL12.GL_BGRA;

public class TextureLoader {

	public int textureID;

	public TextureLoader() {
		textureID = glGenTextures();
		
        glBindTexture(GL_TEXTURE_2D, textureID);
        
        //Setup wrap mode
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL12.GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL12.GL_CLAMP_TO_EDGE);

        //Setup texture scaling filtering
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
	}
	
    public int loadTexture(int[] pixels, int width, int height) {
        // Bind our texture before uploading: ImGui binds its own textures each
        // frame, so without this the upload would target the wrong texture.
        glBindTexture(GL_TEXTURE_2D, textureID);

        // Send texel data to OpenGL. internalFormat must be a base/sized format
        // (GL_RGBA8): GL_BGRA is only valid as the pixel-data 'format', not as
        // internalFormat. Windows drivers tolerate GL_BGRA there, but the strict
        // macOS Core profile rejects it (GL_INVALID_ENUM) and nothing renders.
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, width, height, 0, GL_BGRA, GL_UNSIGNED_BYTE, pixels);

        //Return the texture ID so we can bind it later again
        return textureID;
    }
}