#
# $Id$
#
# Copyright (C) 1997-1999 by Dimitri van Heesch.
#
# Permission to use, copy, modify, and distribute this software and its
# documentation under the terms of the GNU General Public License is hereby 
# granted. No representations are made about the suitability of this software 
# for any purpose. It is provided "as is" without express or implied warranty.
# See the GNU General Public License for more details.
#
# All output generated with Doxygen is not covered by this license.
#
# TMake project file for doxygen

TEMPLATE     =	doxygen.t
CONFIG       =	console qt warn_on release #debug
HEADERS      =	doxygen.h scanner.h classdef.h classlist.h memberdef.h \
                membername.h index.h memberlist.h definition.h \
                entry.h logos.h instdox.h message.h code.h \
                filedef.h util.h cppvalue.h constexp.h \
		outputgen.h outputlist.h htmlgen.h latexgen.h tag.h \
	        filename.h defargs.h groupdef.h gifenc.h diagram.h image.h \
		namespacedef.h version.h language.h translator.h \
		translator_nl.h translator_se.h translator_cz.h translator_fr.h \
		translator_it.h formula.h debug.h
SOURCES      =	doxygen.cpp scanner.cpp classdef.cpp classlist.cpp memberdef.cpp \
	        membername.cpp index.cpp memberlist.cpp \
		entry.cpp logos.cpp instdox.cpp message.cpp code.cpp \
                config.cpp filedef.cpp util.cpp groupdef.cpp \
                outputgen.cpp outputlist.cpp htmlgen.cpp latexgen.cpp mangen.cpp \
	        cppvalue.cpp ce_lex.cpp ce_parse.cpp pre.cpp \
		tag.cpp filename.cpp declinfo.cpp defargs.cpp define.cpp \
		diagram.cpp gifenc.cpp image.cpp namespacedef.cpp \
		version.cpp language.cpp definition.cpp formula.cpp debug.cpp
win32:INCLUDEPATH += .
TARGET       =	../bin/doxygen
OBJECTS_DIR  =  ../objects