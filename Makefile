EMACS ?= emacs
CASK ?= cask
EASK ?= eask

install:
	$(EASK) package
	$(EASK) install

compile:
	$(EASK) compile

ci: clean autoloads install compile

all: clean autoloads compile

autoloads:
	$(EASK) generate autoloads

clean:
	$(EASK) clean all

.PHONY: all autoloads clean
