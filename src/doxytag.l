/******************************************************************************
 *
 * $Id$
 *
 * Copyright (C) 1997-1999 by Dimitri van Heesch.
 *
 * Permission to use, copy, modify, and distribute this software and its
 * documentation under the terms of the GNU General Public License is hereby 
 * granted. No representations are made about the suitability of this software 
 * for any purpose. It is provided "as is" without express or implied warranty.
 * See the GNU General Public License for more details.
 *
 * All output generated with Doxygen is not covered by this license.
 *
 */

%{
/*
 *	includes
 */
#include <stdio.h>
#include <iostream.h>
#include <assert.h>
#include <ctype.h>

#include <qstring.h>  
#include <qstrlist.h>
#include <qfileinf.h>
#include <qfile.h>
#include <qdict.h>
#include <qtstream.h>
#include <qdir.h>
  
#include "version.h"
#include "suffixtree.h"
#include "searchindex.h"
#include "logos.h"
  
struct MemberDef
{
  QString name;
  QString anchor;
  QString args;
};  
  
struct ClassDef
{
  QString  name;
  QStrList bases;
  QString  fileName;
  bool isFile;
  QList<MemberDef> memberList;
};  

QList<ClassDef> classList;
QDict<ClassDef> classDict(1009);
QList<ClassDef> fileList;
QDict<ClassDef> fileDict(1009);

static bool genTag;
static bool genIndex;

static QStrList bases;
static QString  inputString;
static int      inputPosition;
static QString  yyFileName;
static int      yyLineNr;
static QString  classFile;
static QString  memberRef;
static QString  memberName;
static QString  memberArgs;
static QString  className;
//static bool     newClass;
static QString  docBaseLink;
static QString  docAnchor;
static QString  docRefName;
static bool     nameBug;
static SearchIndex searchIndex;

#define YY_NEVER_INTERACTIVE 1

/* -----------------------------------------------------------------
 */
#undef	YY_INPUT
#define	YY_INPUT(buf,result,max_size) result=yyread(buf,max_size);

static int yyread(char *buf,int max_size)
{
    int c=0;
    while( c < max_size && inputString[inputPosition] )
    {
	*buf = inputString[inputPosition++] ;
	c++; buf++;
    }
    return c;
}

static void addClass(const char *clName)
{
  if (classDict[clName]==0)
  {
    ClassDef *cd=new ClassDef;
    cd->name=clName;
    cd->fileName=yyFileName;
    cd->isFile=FALSE;
    classList.append(cd);
    classDict.insert(clName,cd);
  }
}

static void addFile(const char *fName)
{
  if (classDict[fName]==0)
  {
    ClassDef *fd=new ClassDef;
    fd->name=fName;
    fd->fileName=yyFileName;
    fd->isFile=TRUE;
    classList.append(fd);
    classDict.insert(fName,fd);
  }
}

static void addBases(const char *clName)
{
  ClassDef *cd=0;
  if (clName && (cd=classDict[clName])) cd->bases=bases;
}

static void addMember(const char *memName,const char *memRef,const char *memArgs)
{
  ClassDef *cd=classList.last();
  MemberDef *md;
  md=new MemberDef;
  md->name=memName;
  md->anchor=memRef; 
  md->args=memArgs;
  cd->memberList.append(md);
}

static void addReference()
{
  //printf("addReference() key: %s ref:%s\n",
  //  docRefName.data(),(docBaseLink+"#"+docAnchor).data());
  if (genIndex && docRefName.length()>0 && docBaseLink.length()>0)
  {
    if (docAnchor.length()==0)
      searchIndex.addReference(docRefName,docBaseLink);
    else
      searchIndex.addReference(docRefName,docBaseLink+"#"+docAnchor);
    searchIndex.addWord(docRefName,docRefName,TRUE);
  }
}

QString unhtmlify(const char *str)
{
  QString result;
  const char *p=str;
  char c;
  while ((c=*p)!='\0')
  {
    if (c!='&') { result+=c; p++; }
    else
    {
      if (strncmp(p,"&amp;",5)==0)     { result+='&'; p+=5; }	
      else if (strncmp(p,"&lt;",4)==0) { result+='<'; p+=4; }
      else if (strncmp(p,"&gt;",4)==0) { result+='>'; p+=4; }
	else /* should not happen */     { result+='&'; p++; }
    }
  }
  return result;
}

%}

%x Start
%x SearchClassFile
%x ReadClassFile
%x CheckClassName
%x ReadClassName
%x SearchMemberRef
%x ReadMemberRef
%x SearchMemberName
%x ReadMemberName
%x ReadOperator
%x SearchBaseClasses
%x ReadBaseClass
%x SearchRefName
%x ReadRefName
%x SearchArgs
%x ReadArgs
%x SearchWords
%x SkipHTMLTag
%x CheckConstructor
%x SkipPreformated

%%

<Start>^"<li>"  		   { 
				     BEGIN( SearchClassFile );
				   } 
<Start>^"<h1 align=center>"	   { // Qt variant
  				     BEGIN( ReadClassName );
			           }
<Start>^"<h1>"	   		   { // Doxygen variant
  				     BEGIN( ReadClassName );
			           }
<Start>^"Inherits "		   {
  				     //printf("Inherits found\n");
  				     BEGIN( SearchBaseClasses );
  				   }
<Start>^"<h3 class=\"fn\">"/[a-z_A-Z0-9] { // needed due to inconsistency in the Qt docs
  				     BEGIN( CheckConstructor );
				   }
<Start>"<pre>"			   { 
  				     BEGIN( SkipPreformated );
				   }
<Start>"<a name=\""		   {
  				     BEGIN( SearchWords );
  				   }
<Start>"<"			   { 
  				     BEGIN( SkipHTMLTag ); 
				   }
<Start>"&"[a-zA-Z]+";"
<Start>[a-z_A-Z][a-z_A-Z0-9]*	   {
  				     //printf("tag: %s#%s ref: %s word: `%s'\n",
				     // docBaseLink.data(),docAnchor.data(),
				     // docRefName.data(),yytext);
  				     if (genIndex && docRefName.length()>0 && yyleng>2)
				       searchIndex.addWord(docRefName,
					                   yytext,FALSE
							  );
  				   }
<SkipPreformated>"</pre>"	   {
  				     BEGIN( Start );
  				   }
<SkipPreformated>[^\<]+		   
<CheckConstructor>[a-z_A-Z0-9~:]+  {
  				     QString s=yytext;
				     if (s.find("::")!=-1)
				     {
				       docRefName=yytext;
				       addReference();
				       nameBug=TRUE;
				     }
				     else
				     {
				       nameBug=FALSE;
				     }
				     BEGIN( Start );
  				   }
<SearchWords>[a-z_A-Z0-9]+	   {
  				     docAnchor = yytext;
				     if (docAnchor=="details")
				     {
				       docRefName=className.copy();
				       addReference();
  				       BEGIN( Start );
				     }
				     else
				     {
				       BEGIN( SearchRefName );
				     }
  				   }
<SearchRefName>"\" doxytag=\""	   {
  				     BEGIN( ReadRefName ); 
  				   }
<SearchRefName>"\"></a>"	   {
  				     if (nameBug)
				       BEGIN( Start );
				     else
				       BEGIN( ReadRefName );
  				   }

<ReadRefName>[a-z_A-Z0-9:\.\+\-]*"operator"[ \t]*("new"|"delete"|("&amp;"("&amp"|"=")*)|("&gt;"("&gt;"|"=")*)|("&lt;"("&lt;"|"=")*)|("-&gt;"[*]*)|[+\-*%/|~!=,\^]|[+\-*%/\^!|~=\[(][=|+\-\])]) { // hmm, looks impressive :-)
  				     docRefName=unhtmlify(yytext);
				     addReference();
				     BEGIN( Start );
  				   }
<ReadRefName>[a-z_A-Z0-9~:\.\+\-]+       {
  				     //printf("ReadRef=%s\n",yytext);
  				     docRefName=yytext;
				     addReference();
				     BEGIN( Start );
  				   }
<SearchBaseClasses>"<a "[a-z_A-Z0-9 .:\=\"\-\+\/\@]+">" {
  				     //printf("Search %s\n",yytext);
  				     BEGIN( ReadBaseClass );
				   }  
<SearchBaseClasses>\n		   {
  				     addBases(className);
				     BEGIN( Start );
  				   }
<ReadBaseClass>[a-z_A-Z0-9]+	   {
  				     bases.append(yytext);
				     BEGIN( SearchBaseClasses );
  				   }
<SearchClassFile>"<a class=\"el\" href=\""	   {
  				     BEGIN( ReadClassFile ); 
  				   }
<SearchClassFile>"<a href=\""	   {
  				     BEGIN( ReadClassFile ); 
  				   }
<ReadClassName>[a-z_A-Z0-9:\.\-\+]+ {
  				     className=yytext;
				     BEGIN( CheckClassName);
  				   }
<CheckClassName>"Class Reference"  {
  				     //printf("className=%s\n",className.data());
				     addClass(className);
				     BEGIN( Start );
  				   }
<CheckClassName>"File Reference"   {
  				     //printf("className=%s\n",className.data());
				     addFile(className);
				     BEGIN( Start );
  				   }
<CheckClassName>[a-z_A-Z0-9]+	   { // not a class file
  				     className.resize(0);
				     BEGIN( Start );
  				   }
<ReadClassFile>[a-z_A-Z0-9.\-\+]+  {
  			             classFile=yytext;
				     BEGIN( SearchMemberRef );
  				   }
<SearchMemberRef>"#"		   {
				     BEGIN( ReadMemberRef );
				   }
<ReadMemberRef>[a-z_A-Z0-9]+	   {
				     memberRef=yytext;
				     BEGIN( SearchMemberName );
				   }
<SearchMemberName>"<strong>"	   {
			             BEGIN( ReadMemberName );
				   }
<SearchMemberName>[a-z_A-Z~]	   {
  			             unput(*yytext);
				     BEGIN( ReadMemberName );
  				   }
<ReadMemberName>"operator"	   { 
  				     memberName="operator";
  				     BEGIN( ReadOperator );
				   }
<ReadOperator>[+\-*/%\^&|~!=()\[\]]  { memberName+=*yytext; } 
<ReadOperator>"&lt;"		   { memberName+="<"; }
<ReadOperator>"&gt;"		   { memberName+=">"; }
<ReadOperator>"new"		   { memberName+=" new"; }
<ReadOperator>"delete"		   { memberName+=" delete"; }
<ReadOperator>"<"		   { BEGIN( SearchArgs ); }
<ReadMemberName>[a-z_A-Z0-9]+	   {
				     memberName=yytext;
  			             BEGIN( SearchArgs );
			           }  
<SearchArgs>"</a>"		   { 
  				     //printf("SearchArg className=%s memberName=%s\n",className.data(),memberName.data());
				     if (className.length()>0 && memberName.length()>0)
				       BEGIN( ReadArgs ); 
				     else
				       BEGIN( Start );
				   }
<ReadArgs>"&amp;"		   { memberArgs+="&"; }
<ReadArgs>"&lt;"		   { memberArgs+="<"; }
<ReadArgs>"&gt;"		   { memberArgs+=">"; }
  /*
<ReadArgs>[{}]			   { // handle enums
  				     memberArgs.resize(0);
				     addMember(memberName,memberRef,memberArgs);
				     if (*yytext=='}')
				       BEGIN( Start );
				     else
				       BEGIN( SearchClassFile );
  				   }
  */
<ReadArgs>"<"|"\n"		   {
                                     //printf("adding member %s\n",memberName.data());
				     memberArgs=memberArgs.stripWhiteSpace();
				     //if (newClass)
				     //{
				     //  newClass=FALSE;
				     //  addClass(className);
				     //}
				     addMember(memberName,memberRef,memberArgs);
				     memberArgs.resize(0);
				     if (*yytext=='<')
				       BEGIN( SkipHTMLTag);
				     else
				       BEGIN( Start );
  				   }
<ReadArgs>.			   { memberArgs+=(*yytext)&0x7f; }
<SkipHTMLTag>">"		   { BEGIN( Start ); }
<SkipHTMLTag>[a-zA-Z]+		   
<*>.
<*>\n				   { yyLineNr++; 
  				     if (YY_START!=SkipHTMLTag) BEGIN( Start ); 
				   }

%%

/*@ ----------------------------------------------------------------------------
 */


void parse(QString &s)
{
  bases.clear();
  nameBug       = FALSE;
  //newClass      = TRUE;
  inputString   = s;
  inputPosition = 0;
  yyLineNr      = 0;
  tagYYrestart( tagYYin );
  BEGIN( Start );
  tagYYlex();
  //printf("Number of lines scanned: %d\n",yyLineNr);
}

void parseFile(QFileInfo &fi)
{
  fprintf(stderr,"Parsing file %s...\n",fi.fileName().data());
  QFile f(fi.absFilePath());
  if (f.open(IO_ReadOnly))
  {
    yyFileName = fi.fileName();
    className.resize(0);
    memberName.resize(0);
    //printf("Parsing file %s...\n",fi.fileName().data());
    QString input(fi.size()+1);
    docBaseLink=fi.fileName();
    docRefName=fi.fileName().copy();
    searchIndex.addReference(docRefName,docBaseLink);
    searchIndex.addWord(docRefName,docRefName,TRUE);
    f.readBlock(input.data(),fi.size());
    input.at(fi.size())='\0';
    parse(input);
  }
  else
  {
    fprintf(stderr,"Warning: Cannot open file %s\n",fi.fileName().data());
  }
}

void parseFileOrDir(const char *fileName)
{
  QFileInfo fi(fileName);
  if (fi.exists())
  {
    if (fi.isFile())
    {
      parseFile(fi);
    }
    else if (fi.isDir())
    {
      QDir dir(fileName);
      dir.setFilter( QDir::Files );
      dir.setNameFilter( "*.html" );
      const QFileInfoList *list = dir.entryInfoList();
      QFileInfoListIterator it( *list );
      QFileInfo *cfi;
      for ( it.toFirst() ; (cfi=it.current()) ; ++it)
      {
	if (cfi->isFile())
	{
	  parseFile(*cfi);
	}
      }
    }
  }
  else
  {
    fprintf(stderr,"Warning: File %s does not exist\n",fileName);
  }
}

void usage(const char *name)
{
  fprintf(stderr,"Doxytag version %s\nCopyright Dimitri van Heesch 1997-1999\n\n",
      versionString);
  fprintf(stderr,"  Generates a tag file and/or a search index for a set of HTML files\n\n");
  fprintf(stderr,"Usage: %s [-t tag_file] [-s index_file] [ html_file [html_file...] ]\n",name);
  fprintf(stderr,"Options:\n");
  fprintf(stderr,"  -t <tag_file>   Generate tag file <tag_file>.\n");
  fprintf(stderr,"  -s <index_file> Generate search index <index_file>.\n\n");
  fprintf(stderr,"If no HTML files are given all files in the current dir that\n"
                 "have a .html extension are parsed.\n\n");
  exit(1);
}

const char *getArg(int argc,char **argv,int &optind,const char c)
{
  char *s=0;
  if (strlen(&argv[optind][2])>0)
    s=&argv[optind][2];
  else if (optind+1<argc)
    s=argv[++optind];
  else
  {
    fprintf(stderr,"option -%c requires an argument\n",c);
    exit(1);
  }
  return s;
}

int main(int argc,char **argv)
{
  QString tagName;
  QString indexName;
  
  int optind=1;
  const char *arg;
  while (optind<argc && argv[optind][0]=='-')
  {
    switch(argv[optind][1])
    {
      case 't':
	arg=getArg(argc,argv,optind,'t');
	tagName=arg;
	break;
      case 's':
	arg=getArg(argc,argv,optind,'s');
	indexName=arg;
	break;
      case 'h':
      case '?':
        usage(argv[0]);
        break;
      default:
	fprintf(stderr,"Unknown option -%c\n",argv[optind][1]);
	usage(argv[0]);
    }
    optind++;
  }
  
  genTag   = tagName.length()>0;
  genIndex = indexName.length()>0;

  if (!genTag && !genIndex)
  {
    fprintf(stderr,"Nothing to do !\n\n");
    usage(argv[0]);
  }
  
  int i;
  if (optind>=argc)
  {
    parseFileOrDir(".");
  }
  else
  {
    for (i=optind;i<argc;i++)
    {
      parseFileOrDir(argv[i]);
    }
  }
  if (genIndex)
  {
    printf("Writing search index\n");
    if (!searchIndex.saveIndex(indexName))
    {
      fprintf(stderr,"Error: Could not write search index\n");
    }
    QFileInfo fi(indexName);
    if (fi.exists())
    {
      QString dir=fi.dir().absPath();
      fi.setFile(dir+"/search.gif");
      if (!fi.exists()) writeSearchButton(dir);
      fi.setFile(dir+"/doxygen.gif");
      if (!fi.exists()) writeLogo(dir);
      fi.setFile(dir+"/search.cgi");
      if (!fi.exists())
      {
        QFile f(dir+"/search.cgi");
	if (f.open(IO_WriteOnly))
	{
	  QTextStream t(&f);
	  t << "#!/bin/sh" << endl 
	    << "DOXYSEARCH=" << endl 
	    << "DOXYPATH=" << endl
	    << "if [ -f $DOXYSEARCH ]" << endl
	    << "then" << endl
	    << "  $DOXYSEARCH $DOXYPATH" << endl 
	    << "else" << endl
	    << "  echo \"Content-Type: text/html\"" << endl
	    << "  echo \"\"" << endl
	    << "  echo \"<H1>Error: $DOXYSEARCH not found. Check cgi script!\"" << endl
	    << "fi" << endl;
          f.close();
	}	  
	else
	{
	  fprintf(stderr,"Error: could not open file %s for writing\n",(dir+"/search.cgi").data());
	}
      }
    }
  }
  if (genTag)
  {
    QFile f(tagName);
    if (f.open(IO_WriteOnly))
    {
      QTextStream t(&f);
      ClassDef *cd=classList.first();
      while (cd)
      {
	if (cd->isFile) t << "&"; else t << ">";
	t << cd->name << ":";
        char *base=cd->bases.first();
        while (base)
	{
	  t << base << "?";
	  base=cd->bases.next();
	}
	if (!cd->isFile) t << " \"" << cd->fileName << "\"";
	t << endl; 
	MemberDef *md=cd->memberList.first();
	while (md)
	{
	  t << md->name << " " << md->anchor << " \"" << md->args << "\"" << endl;
	  md=cd->memberList.next();
	}
	cd=classList.next();
      }
    }
    else
    {
      fprintf(stderr,"Error: Could not write tag file %s\n",tagName.data());
    }
  }
  return 0;
}

extern "C" {
int	tagYYwrap()	{ return 1 ; }
};