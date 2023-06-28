package com.widedot.m6809.gamebuilder.spi;

import java.util.Collections;
import java.util.List;
import com.widedot.m6809.gamebuilder.spi.foo.FooFactory;

public interface Plugin {

  default List<FooFactory> getFooFactories() {
    return Collections.emptyList();
  }
}
