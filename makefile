# Makefile for building Mobile OPAC software.
#
# Recommended sequence...
#
# ...for rebuilding all software.
# make clean
# make
# make build
#
# ...for rebuilding just the minimized software.
# make clean-build
# make build
#


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
CStoJS = node $(dirDev)/node_modules/coffee-script/bin/coffee -c -b
# Minify javascript using Google closure compiler.
JStoMAP = java -jar $(dirDev)/closure/compiler.jar
# Prepare build directory containing minified javascript and other files using rsync.
Build = rsync -av --del --delete --exclude=zzz/ --exclude=*~ --exclude=.DS_Store
# Generate HTML documentation.
CStoHTML = node $(dirDev)/node_modules/docco/bin/docco
TXTtoHTML = python $(dirDev)/asciidoc/asciidoc.py


# Main modules.
Main = \
	$(dirSrc)/settings_sitka.map \
	$(dirSrc)/settings_kcls.map \
	$(dirSrc)/mobile_opac.map

# Utility modules.
Utility = \
	$(dirSrc)/plugin.map \
	$(dirSrc)/template.map \
	$(dirSrc)/messages.map \
	$(dirSrc)/load_spinner.map \
	$(dirSrc)/login_bar.map \
	$(dirSrc)/login_window.map

# Modules for searching public catalogue.
Opac = \
	$(dirSrc)/opac/search_bar.map \
	$(dirSrc)/opac/search_result.map \
	$(dirSrc)/opac/edit_hold.map \
	$(dirSrc)/opac/ou_tree.map \
	$(dirSrc)/opac/sort.map

# Modules for handling my account.
Account = \
	$(dirSrc)/account/summary.map \
	$(dirSrc)/account/fines.map \
	$(dirSrc)/account/checkouts.map \
	$(dirSrc)/account/holds.map

# Modules for wrapping up Evergreen API layer.
Eg = \
	$(dirSrc)/eg/eg_api.map \
	$(dirSrc)/eg/fieldmapper.map \
	$(dirSrc)/eg/date.map \
	$(dirSrc)/eg/fm_datatypes.map \
	$(dirSrc)/dojo/fieldmapper/fmall_1_6.map \
	$(dirSrc)/dojo/fieldmapper/fmall_2_0.map

# External javascript libraries.
Lib = \
	$(dirSrc)/lib/jmod.map \
	$(dirSrc)/lib/jquery_blockUI.map \
	$(dirSrc)/lib/jsdeferred.map \
	$(dirSrc)/lib/json2.map \
	$(dirSrc)/lib/md5.map


# Default rule to compile all .coffee files to .js files
# and to minified .js files
all : $(Main) $(Utility) $(Opac) $(Account) $(Eg) $(Lib)


.PHONY : all build clean clean-source clean-min clean-build docs

# Declare the important suffixes for this makefile
.SUFFIXES:
.SUFFIXES: .coffee .js .txt .html
# Do not delete intermediate javascript files.
.PRECIOUS : %.js


# Pattern rules
#
# Transform javascript files to source map files in the source directory
# and minified javascript files in the min directory.
$(Main) $(Utility) $(Opac) $(Account) $(Eg) $(Lib) : %.map : %.js
	$(JStoMAP) --js=$< --create_source_map $@ --js_output_file=$(subst $(dirSrc),$(dirMin),$<)


# Implicit pattern rules
#
# Transform coffeescripts to javascripts.
%.js : %.coffee ; $(CStoJS) $< > $@
# Transform text files to HTML pages.
%.html : %.txt ; $(TXTtoHTML) $< > $@


# Make main design document.
doc : $(dirDoc)/design.html

# Make source-level documents.
docs :
	$(CStoHTML) $(dirSrc)/{.,opac,account,eg}/*.coffee

clean_docs :
	-rm $(dirDoc)/*.html
	-rm -rf $(dirDocs)

# Build all minified .js files and other files to the build directory.
build :
	-mkdir $(dirBuild)
	$(Build) --exclude=dojo/ --include=.js  $(dirMin)/ $(dirBuild)/js
	$(Build)                 --include=.css       css  $(dirBuild)
	$(Build)                 --include=.gif    images  $(dirBuild)
	$(Build)                                   *.html  $(dirBuild)
	-ln -s ../../../../js/dojo $(dirBuild)/js/dojo
clean-build :
	-rm -rf $(dirBuild)

# Remove compiled files in source/ and min/ and build/ directories.
clean : clean-source clean-min clean-build

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


kcls : all
	-rm index.html
	ln -s index_kcls.html index.html
	-rm build/index.html
	(cd build; ln -s index_kcls.html index.html)
	-rm src/dojo/fieldmapper/fmall.js
	(cd src/dojo/fieldmapper; ln -s fmall_2_0.js fmall.js)
	-rm min/dojo/fieldmapper/fmall.js
	(cd min/dojo/fieldmapper; ln -s fmall_2_0.js fmall.js)


sitka : all
	-rm index.html
	ln -s index_sitka.html index.html
	-rm build/index.html
	(cd build; ln -s index_sitka.html index.html)
	-rm src/dojo/fieldmapper/fmall.js
	(cd src/dojo/fieldmapper; ln -s fmall_2_0.js fmall.js)
	-rm min/dojo/fieldmapper/fmall.js
	(cd min/dojo/fieldmapper; ln -s fmall_2_0.js fmall.js)
