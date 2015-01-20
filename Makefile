SHELL = /bin/sh
BUNDLE ?= bundle

SRCDIR ?= src
TARGETDIR = $(SRCDIR)

IBA_TARGET = $(TARGETDIR)/drink/IBA
TARGETS = $(IBA_TARGET)

all: menu | $(TARGETDIR)

menu: iba
	find $(TARGETDIR) -maxdepth 3 -type f | \
		sed -e 's/$(TARGETDIR)\///' -e 's/\.md//' | \
		sed -e 's/\// \/ /g'

clean:
	rm -rf $(TARGETS)

bundle:
	$(BUNDLE) install --quiet

iba: | $(IBA_TARGET)
$(IBA_TARGET):
	$(BUNDLE) exec ruby bin/iba update $@

test: test-iba test-menu
test-iba: bundle
	$(BUNDLE) exec ruby bin/iba update $(IBA_TARGET) SAZERAC
	cat $(IBA_TARGET)/Sazerac.md
test-menu:
	make menu

.PHONY: all clean menu iba bundle test test-iba test-menu
.DELETE_ON_ERROR:
