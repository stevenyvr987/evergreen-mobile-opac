#!/bin/sh

# A variation of http://tab.snarc.org/post/2010/11/17/darcs_mirrors_to_git/
# to incrementally mirror a darcs repo to a git repo

Darcs=darcs
DarcsExport="darcs-fastconvert export"
Git=git
GitImport="$Git fast-import"

if [ ! -d "_darcs" ]; then
	echo "Not a darcs repository"
	exit 1
fi

if [ ! -d ".git" ]; then
	echo "Initializing git mirror"
	$Git init
fi

# Set mark files for darcs repo
DarcsMark=.git/darcs.mark
WriteMarks="--write-marks=$DarcsMark"
ReadMarks=""
if [ -f $DarcsMark ]; then ReadMarks="--read-marks=$DarcsMark"; fi

# Set mark files for git repo
GitMark=.git/git.mark
ExportMarks="--export-marks=$GitMark"
ImportMarks=""
if [ -f $GitMark ]; then ImportMarks="--import-marks=$GitMark"; fi

# Incrementally mirror darcs repo to git repo
$DarcsExport $ReadMarks $WriteMarks | $GitImport $ImportMarks $ExportMarks

# Do a quick clean of git repo
$Git gc

exit 0

