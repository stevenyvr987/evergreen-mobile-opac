# Makefile for building Mobile OPAC software.
#
# Recommended sequences...
#
# ...while developing code as coffeescript files
# make coffee
#
# ...for rebuilding all software and documentation
# make clean
# make
#
# ...for rebuilding minimized software for installing remotely
# make clean-build build
#
# ...for rebuilding source-level HTML documentation
# make clean-docs docs
#
# ...for updating remote source-code repository
# make mirror push


# Source directory contains coffeescript, unminified javascript,
# and map files compiled as a result of minification.
dirSrc = src
# Min directory contains minified javascript files.
dirMin = min
# Build directory contains javascript and other files intended to be installed on target system.
dirBuild = build
# Directory containing main design document.
dirDoc = doc
# Directory containing source code documents.
dirDocs = docs
# Directory containing locally installed development tools
dirDev = dev


# Compile coffeescript to javascript using the coffee compiler.
CStoJS = node $(dirDev)/node_modules/coffee-script/bin/coffee -bc
# Minify javascript using Google closure compiler.
JStoMAP = java -jar $(dirDev)/closure/compiler.jar
# Prepare build directory containing minified javascript and other files using rsync.
Build = rsync -av --del --delete --exclude=.DS_Store
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


# Main modules
Main = $(dirSrc)/*.map

# Modules for searching public catalogue
Opac = $(dirSrc)/opac/*.map

# Modules for handling my account
Account = $(dirSrc)/account/*.map

# Modules for wrapping up Evergreen API layer
Eg = $(dirSrc)/eg/*.map $(dirSrc)/dojo/fieldmapper/*.map

# External javascript libraries
Lib = $(dirSrc)/lib/*.map


# Default rule to convert .coffee files to
# * minified .js files ready for testing locally
# * minified .js files ready for installing remotely
# * HTML documentation
all : min build docs doc

# Compile .coffee files to minified .js files
min : $(Main) $(Opac) $(Account) $(Eg) $(Lib)


.PHONY : all min build docs doc clean clean-source clean-min clean-build coffee

# Declare the important suffixes for this makefile
.SUFFIXES:
.SUFFIXES: .coffee .js .txt .html
# Do not delete intermediate javascript files.
.PRECIOUS : %.js


# Pattern rules
#
# Transform javascript files to source map files in the source directory
# and minified javascript files in the min directory.
$(Main) $(Opac) $(Account) $(Eg) $(Lib) : %.map : %.js
	$(JStoMAP) --js=$< --create_source_map $@ --js_output_file=$(subst $(dirSrc),$(dirMin),$<)


# Run the coffeescript compiler in watch mode on the src folder so that as
# Coffeescript source files are modified they are compiled into Javascript
# files.
coffee :
	node $(dirDev)/node_modules/coffee-script/bin/coffee -wbc $(dirSrc) $(dirSrc)/lib

# Make main design document.
doc : $(dirDoc)/design.html

# Make source-level documents.
docs :
	-rm -rf $(dirDocs)
	$(CStoHTML) $(dirSrc)/*.coffee $(dirSrc)/opac/*.coffee $(dirSrc)/account/*.coffee $(dirSrc)/eg/*.coffee

clean-docs :
	-rm $(dirDoc)/*.html
	-rm -rf $(dirDocs)

# Build all minified .js files and other files to the build directory.
build : min
	-mkdir $(dirBuild)
	$(Build) --exclude=dojo/ --include=.js  $(dirMin)/ $(dirBuild)/js
	$(Build)                 --include=.css       css  $(dirBuild)
	$(Build)                 --include=.gif    images  $(dirBuild)
	$(Build)                                   *.html  $(dirBuild)
	-ln -s ../../../../js/dojo $(dirBuild)/js/dojo
clean-build :
	-rm -rf $(dirBuild)

# Remove compiled files in the various target directories.
clean : clean-source clean-min clean-build clean-docs

# Remove source map files in source/.
# Ignore errors in the process.
clean-source :
	-rm $(dirSrc)/*.js
	-rm $(dirSrc)/opac/*.js
	-rm $(dirSrc)/account/*.js
	-rm $(dirSrc)/eg/*.map
	-rm $(dirSrc)/eg/date.js
	-rm $(dirSrc)/eg/eg_api.js
	-rm $(dirSrc)/eg/fieldmapper.js
	-rm $(dirSrc)/lib/*.map
	-rm $(dirSrc)/dojo/fieldmapper/*.map

# Remove the minified javascript files in min/.
# Ignore errors in the process.
clean-min :
	-rm -rf $(dirMin)
	-mkdir -p $(dirMin)/opac
	-mkdir -p $(dirMin)/account
	-mkdir -p $(dirMin)/eg
	-mkdir -p $(dirMin)/lib
	-mkdir -p $(dirMin)/dojo/fieldmapper


kcls : min
	-rm index.html
	ln -s index_kcls.html index.html
	-rm build/index.html
	(cd build; ln -s index_kcls.html index.html)
	-rm src/dojo/fieldmapper/fmall.js
	(cd src/dojo/fieldmapper; ln -s fmall_2_0.js fmall.js)
	-rm min/dojo/fieldmapper/fmall.js
	(cd min/dojo/fieldmapper; ln -s fmall_2_0.js fmall.js)


sitka : min
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
