package com.widedot.toolbox.debug;

import imgui.ImGui;
import imgui.app.Application;
import imgui.app.Configuration;

public class WDDebug extends Application {
    @Override
    protected void configure(Configuration config) {
        config.setTitle("Dear ImGui is Awesome!");
    }

    @Override
    public void process() {
        ImGui.text("Hello, World!");
    }
    
    public WDDebug() {
    	launch(this);
    }

}