package com.widedot.toolbox.text.ascii2bas.plugin;

import java.util.Arrays;
import java.util.List;
import com.widedot.m6809.gamebuilder.spi.Plugin;
import com.widedot.m6809.gamebuilder.spi.foo.FooFactory;

public class FooPlugin implements Plugin {

  @Override
  public List<FooFactory> getFooFactories() {
    return Arrays.asList(
        new FooFactoryImpl()
    );
  }
}
