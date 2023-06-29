package com.widedot.m6809.gamebuilder.spi;

import java.util.Collections;
import java.util.List;
import com.widedot.m6809.gamebuilder.spi.fileprocessor.FileProcessorFactory;

public interface Plugin {

  default List<FileProcessorFactory> getFileProcessorFactories() {
    return Collections.emptyList();
  }
}
