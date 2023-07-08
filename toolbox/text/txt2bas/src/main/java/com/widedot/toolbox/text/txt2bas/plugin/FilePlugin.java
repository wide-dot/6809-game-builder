package com.widedot.toolbox.text.txt2bas.plugin;

import java.util.Arrays;
import java.util.List;
import com.widedot.m6809.gamebuilder.spi.Plugin;
import com.widedot.m6809.gamebuilder.spi.fileprocessor.FileFactory;

public class FilePlugin implements Plugin {

  @Override
  public List<FileFactory> getFileFactories() {
    return Arrays.asList(
        new FileFactoryImpl()
    );
  }
}
