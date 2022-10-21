package com.widedot.m6809.oldgamebuilder.to8.builder;

import lombok.AccessLevel;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.experimental.FieldDefaults;

@AllArgsConstructor
@FieldDefaults(level = AccessLevel.PRIVATE)
@Getter
public class Palette
{
	String parentName;
	String name;
	String fileName;
}
