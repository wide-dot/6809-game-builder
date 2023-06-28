package com.widedot.toolbox.text.ascii2bas.plugin;

import com.widedot.m6809.gamebuilder.spi.foo.Foo;
import com.widedot.m6809.gamebuilder.spi.foo.FooFactory;

public class FooFactoryImpl implements FooFactory {

  @Override
  public String name() {
    return "foo";
  }

  @Override
  public Foo build() {
    return new FooImpl();
  }
}
