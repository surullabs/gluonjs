# Copyright 2015 Surul Software Labs GmbH
# This file is licensed under the MIT License

BIN = ./node_modules/.bin
SRC = $(wildcard src/*.coffee)
LIB = $(SRC:src/%.coffee=lib/%.js)

build: $(LIB)

lib/%.js: src/%.coffee
	@$(BIN)/coffee -bcp $< > $@

test: build
	@$(BIN)/mocha --compilers coffee:coffee-script/register
