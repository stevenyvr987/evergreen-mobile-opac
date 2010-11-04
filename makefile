# Makefile for building Mobile OPAC software.
#
# Recommended sequences...
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

# Compile coffeescript to javascript using the coffee compiler.
CStoJS = coffee -c --no-wrap
# Minify javascript using Google closure compiler.
#JStoMAP = java -jar ~/Downloads/compiler-latest/compiler.jar
JStoMAP = java -jar /Software/compiler-latest/compiler.jar
# Prepare build directory containing minified javascript and other files using rsync.
Build = rsync -av --del --delete --exclude=zzz/ --exclude=*~ --exclude=.DS_Store
# Generate HTML documentation.
JStoHTML = docco
TXTtoHTML = asciidoc

# Main modules.
Main = \
	$(dirSrc)/mobile_opac_sitka.map \
	$(dirSrc)/mobile_opac_kcls.map

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
	$(dirSrc)/opac/search_bar_sitka.map \
	$(dirSrc)/opac/search_bar_kcls.map \
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
	$(dirSrc)/eg/fm_datatypes.map

# External javascript libraries.
Lib = \
	$(dirSrc)/lib/jmod.map \
	$(dirSrc)/lib/jquery-1.4.2.map \
	$(dirSrc)/lib/jquery.blockUI.map \
	$(dirSrc)/lib/jsdeferred.map \
	$(dirSrc)/lib/json2.map \
	$(dirSrc)/lib/md5.map


# Default rule to compile all .coffee files to .js files
# and to minified .js files
all : $(Main) $(Utility) $(Opac) $(Account) $(Eg) $(Lib)

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

# Make design document.
doc : $(dirDoc)/design.html

# Build all minified .js files and other files to the build directory.
build :
	-mkdir $(dirBuild)
	$(Build) --exclude=dojo/ --include=.js  $(dirMin)/ $(dirBuild)/js
	$(Build)                 --include=.css       css  $(dirBuild)
	$(Build)                 --include=.gif    images  $(dirBuild)
	$(Build)                             *.html *.ico  $(dirBuild)
	-ln -s ../../../../js/dojo $(dirBuild)/js/dojo

# Remove compiled files in source/ and min/ and build/ directories.
clean : clean-source clean-min clean-build
# Remove source map files in source/.
# Ignore errors in the process.
clean-source :
	-rm $(dirSrc)/*.map
	-rm $(dirSrc)/opac/*.map
	-rm $(dirSrc)/account/*.map
	-rm $(dirSrc)/eg/*.map
	-rm $(dirSrc)/lib/*.map
# Remove the minified javascript files in min/.
# Ignore errors in the process.
clean-min :
	-rm $(dirMin)/*.js
	-rm $(dirMin)/opac/*.js
	-rm $(dirMin)/account/*.js
	-rm $(dirMin)/eg/*.js
	-rm $(dirMin)/lib/*.js
# Remove and remake build/ and install a symlink to point to collateral files in target system.
clean-build :
	-rm -rf $(dirBuild)

# Do not delete intermediate javascript files.
.PRECIOUS : %.js

.PHONY : all build clean clean-source clean-min clean-build
