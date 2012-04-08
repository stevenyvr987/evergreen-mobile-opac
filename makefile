# Makefile for building Mobile OPAC software.
#
# Recommended sequences...
#
# ...while developing code as coffeescript files
# make coffee
#
# ...for rebuilding all software and documentation for deployment
# make clean
# make
#
# ...for rebuilding minimized software for testing locally
# make build
#
# ...for rebuilding minimized software for installing remotely
# make deply
#
# ...for rebuilding source-level HTML documentation
# make clean-docs docs
#
# ...for updating remote source-code repository
# make mirror push


# Directory containing coffeescript files
dirSrc = src
# Directory containing application files, including html, css, images, and
# javascript files
dirApp = app
# Directory containing all application files,
# including compressed javascript and css files for deployment
dirBuild = build
# Directory containing main design document
dirDoc = doc
# Directory containing source code documents
dirDocs = docs
# Directory containing locally installed development tools
dirDev = dev


# Compile coffeescript to javascript using the coffee compiler.
CStoJS = node $(dirDev)/node_modules/coffee-script/bin/coffee -bc
# Command to optimize javascript files
Build = node $(dirDev)/node_modules/.bin/r.js
# Command to generate a datestamp
BuildDate = node $(dirDev)/build_date.js
# Generate HTML documentation.
CStoHTML = node $(dirDev)/node_modules/docco/bin/docco
TXTtoHTML = python $(dirDev)/asciidoc/asciidoc.py


# Implicit pattern rules
#
# Transform coffeescripts to javascripts.
%.js   : %.coffee ; $(CStoJS) $< > $@
# Transform coffeescripts to HTML pages
# (which are automatically deposited in dirDocs directory).
%.html : %.coffee ; $(CStoHTML) $<
# Transform text files to HTML pages.
%.html : %.txt    ; $(TXTtoHTML) $< > $@


# Default rule to build optimized application files and HTML documentation
all : deploy docs doc


.PHONY : all build deploy docs doc clean clean-build coffee mirror push

# Declare the important suffixes for this makefile
.SUFFIXES:
.SUFFIXES: .coffee .js .txt .html
# Do not delete intermediate javascript files.
.PRECIOUS : %.js


# Run the coffeescript compiler in watch mode on the src folder so that as
# Coffeescript source files are modified they are compiled into Javascript
# files.
coffee :
	$(CStoJS) -w -o $(dirApp)/scripts $(dirSrc)

# Make main design document.
doc : $(dirDoc)/design.html

# Make source-level documents.
docs :
	-rm -rf $(dirDocs)
	$(CStoHTML) $(dirSrc)/*.coffee $(dirSrc)/opac/*.coffee $(dirSrc)/account/*.coffee $(dirSrc)/eg/*.coffee

clean-docs :
	-rm $(dirDoc)/*.html
	-rm -rf $(dirDocs)

# Optimize .js files and .css files in the build directory for development testing
build :
	$(Build) -o $(dirDev)/app.build.js
	$(BuildDate) < $(dirApp)/index.html > $(dirBuild)/index.html
# Optimize .js files and .css files in the build directory for deployment
deploy :
	$(Build) -o $(dirDev)/app.build.js
	$(BuildDate) < $(dirApp)/index.html > $(dirBuild)/index.html
	-ln -s ../../../../js/dojo $(dirBuild)/scripts/dojo
clean-build :
	-rm -rf $(dirBuild)

# Remove compiled files in the various target directories.
clean : clean-build clean-docs


kcls :
	-rm index.html
	ln -s index_kcls.html index.html
	-rm build/index.html
	(cd build; ln -s index_kcls.html index.html)
	-rm src/dojo/fieldmapper/fmall.js
	(cd src/dojo/fieldmapper; ln -s fmall_2_0.js fmall.js)
	-rm min/dojo/fieldmapper/fmall.js
	(cd min/dojo/fieldmapper; ln -s fmall_2_0.js fmall.js)


sitka :
	-rm index.html
	ln -s index_sitka.html index.html
	-rm build/index.html
	(cd build; ln -s index_sitka.html index.html)
	-rm src/dojo/fieldmapper/fmall.js
	(cd src/dojo/fieldmapper; ln -s fmall_2_0.js fmall.js)
	-rm min/dojo/fieldmapper/fmall.js
	(cd min/dojo/fieldmapper; ln -s fmall_2_0.js fmall.js)

# Mirror local darcs repository to local git repository
mirror :
	dev/git_mirror.sh

# Push local git repository to Google Project Hosting site
push :
	git push https://code.google.com/p/evergreen-mobile-opac/
