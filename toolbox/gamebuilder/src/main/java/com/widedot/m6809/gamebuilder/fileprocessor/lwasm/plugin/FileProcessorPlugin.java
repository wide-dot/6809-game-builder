package com.widedot.m6809.gamebuilder.fileprocessor.lwasm.plugin;

import java.util.Arrays;
import java.util.List;
import com.widedot.m6809.gamebuilder.spi.Plugin;
import com.widedot.m6809.gamebuilder.spi.fileprocessor.FileProcessorFactory;

public class FileProcessorPlugin implements Plugin {

  @Override
  public List<FileProcessorFactory> getFileProcessorFactories() {
    return Arrays.asList(
        new FileProcessorFactoryImpl()
    );
  }
}
