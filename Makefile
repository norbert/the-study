TARGETDIR = drink
SRCDIR = src

IBA_TARGET = $(TARGETDIR)/IBA
MCAH_FILE = $(TARGETDIR)/MCAH/Cocktails.md
MCAH_REPOSITORY = $(SRCDIR)/daveturnbull.git
RD_TARGET = $(TARGETDIR)/RD
RD_REPOSITORY = $(SRCDIR)/reiddraper.git
TARGETS = $(IBA_TARGET) $(MCAH_FILE) $(RD_TARGET)

all: bundle iba mcah rd menu | $(TARGETDIR)

menu: iba
	find $(TARGETDIR) $(IBA_TARGET) -maxdepth 1 -type f | sed -e 's/$(TARGETDIR)\///' -e 's/\.md//'

test: bundle
	bundle exec ruby -Ilib bin/iba build $(IBA_TARGET) SAZERAC

clean:
	rm -rf ${SRCDIR} ${TARGETS}

bundle:
	bundle install --quiet

iba: | $(IBA_TARGET)

$(IBA_TARGET):
	bundle exec ruby -Ilib bin/iba build $@

mcah: $(MCAH_FILE)

$(MCAH_REPOSITORY):
	git clone -q git://github.com/daveturnbull/cocktails.git $@

$(MCAH_FILE): | $(MCAH_REPOSITORY)
	mkdir -p $(TARGETDIR)/MCAH
	cp $(MCAH_REPOSITORY)/Cocktails.md $@

rd: $(RD_TARGET)

$(RD_REPOSITORY):
	git clone -q git://github.com/reiddraper/cocktail-recipes.git $@

$(RD_TARGET): | $(RD_REPOSITORY)
	rm -rf $@
	cp -r $(RD_REPOSITORY)/recipes $@
	cd $(RD_TARGET) && \
		for FILE in `find . -name "*.dd"`; do \
			mv "$$FILE" "$${FILE%%.dd}.md"; \
		done
