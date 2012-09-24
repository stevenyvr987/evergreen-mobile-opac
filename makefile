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
# make tag='1.2.3' deploy
#
# ...for rebuilding source-level HTML documentation
# make clean-docs docs
#
# ...for updating remote source-code repository
# make mirror push

# Version tag
tag =
# Directory containing coffeescript files
dirSrc = src
# Directory containing application files, including html, css, images, and
# javascript files
dirApp = app
# Directory containing all application files,
# including compressed javascript and css files for deployment
dirBuild = mobile
# Build directory for deployment; name is appended with a version tag
dirDeploy = $(dirBuild)_$(tag)
# Directory containing main design document
dirDoc = doc
# Directory containing source code documents
dirDocs = docs
# Directory containing locally installed development tools
dirDev = dev
# Path to remote repository
pathRepo = https://code.google.com/p/evergreen-mobile-opac/

# Compile coffeescript to javascript using the coffee compiler.
CStoJS = node $(dirDev)/node_modules/coffee-script/bin/coffee -bc
# Command to optimize javascript files
Build = node $(dirDev)/node_modules/requirejs/bin/r.js
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
	$(CStoJS) -w -o $(dirApp)/js $(dirSrc) > /dev/null

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
build : $(dirDev)/build_date.js
	$(Build) -o $(dirDev)/app.build.js
	node $< < $(dirApp)/index.html > $(dirBuild)/index.html
# Optimize .js files and .css files in the build directory for deployment
deploy : $(dirDev)/build_date.js
	$(Build) -o $(dirDev)/app.build.js
	-mv $(dirBuild) $(dirDeploy)
	node $< < $(dirApp)/index.html > $(dirDeploy)/index.html
	-rm -rf $(dirDeploy)/js/dojo
	-ln -s ../../../../js/dojo $(dirDeploy)/js
	-tar -czf $(dirDeploy).tgz $(dirDeploy)
clean-build :
	-rm -rf $(dirBuild) $(dirDeploy) *.tgz

# Remove compiled files in the various target directories.
clean : clean-build clean-docs

# Mirror local darcs repository to local git repository
mirror :
	dev/git_mirror.sh

# Push local commits and tags to remote repository
push :
	git push $(pathRepo)
	git push --tags $(pathRepo)
