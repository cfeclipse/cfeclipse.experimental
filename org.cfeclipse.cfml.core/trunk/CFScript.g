grammar CFScript;

/*
Copyright (c) 2007 Mark Mandel, Mark Drew

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
*/

options 
{
	output=AST;
}

tokens
{
	FUNCTION_CALL;
	FUNCTION_DECLARATION;
	ARGUMENT_TYPE;
	STRUCT_KEY;
	ELSEIF;
	STRING_CFML;
	STRING;
}

/* Parser */

@parser::header 
{
package org.cfeclipse.cfml.core.parser.antlr;

/*
Copyright (c) 2007 Mark Mandel, Mark Drew

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.	
*/	
}


@lexer::header
{
package org.cfeclipse.cfml.core.parser.antlr;


/*
Copyright (c) 2007 Mark Mandel, Mark Drew

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.	
*/
}

@lexer::members
{
	public static final int COMMENT_CHANNEL = 90;
	
	private static final int CATCH_MODE = 1;
	private static final int NORMAL_MODE = 0;
	
	private int mode = NORMAL_MODE;
	
	private void setMode(int mode)
	{
		this.mode = mode;
	}
	
	private int getMode()
	{
		return this.mode;
	}
}

app : script;

script
	:
	( 
		( 
		COMMENT
		|
			nonBlockStatement 
			|
			ifStatement
			|
			tryStatement
			|
			forStatement
			|
			whileStatement
			|
			doWhileStatement
			|
			switchStatement
			|
			functionDeclaration
		)
	)*
	;
	
nonBlockStatement
	:
	(
		setStatement
		|
		returnStatement
		|
		breakStatement 
	)
	SEMI_COLON
	;
	
setStatement
	:
	/*
	This will allow statements like: (x * y) = 2; 
	But trying to cut it down will either slow it down results 
	in non LL(*) recursive conditions.
	
	I think I will just have to leave it, or I'll come back to it
	and try and get clever.
	*/
	varedSetStatement |
	codeStatement (EQUALS codeStatement)? (EQUALS struct)?
	;

varedSetStatement
  :
  VAR setStatement
  ;


codeStatement
	:
	(
		OPEN_PAREN codeStatement? CLOSE_PAREN
		|
		cfmlBasicStatement 
	)
	;
	
returnStatement
	:
	RETURN^ (codeStatement)?
	;

cfmlBasicStatement
	:
	cfmlValueStatement (OPERATOR codeStatement)?
	;


cfmlValueStatement
	:
	(NOT)? cfmlValue
	;

cfmlValue
	:
	(NUMBER | stringLiteral | cfmlLinking)
	;

cfmlLinking
	:
	hashCfmlLinking
	|
	cfmlBasicLinking
	;

hashCfmlLinking
	:	
	HASH cfmlBasicLinking HASH
	;

cfmlBasicLinking
	:
	cfmlBasic (DOT cfmlBasic)* (OPEN_SQUARE codeStatement CLOSE_SQUARE)*
	;

cfmlBasic
	:
	identifier | function
	;

innerStringCFML
	:
	hashCfmlLinking
	;

stringLiteral
	:
	(
		DOUBLE_QUOTE^ ( innerStringCFML | ESCAPE_DOUBLE_QUOTE | ~(DOUBLE_QUOTE | ESCAPE_DOUBLE_QUOTE | HASH) )* DOUBLE_QUOTE
	)
	|
	(
		SINGLE_QUOTE^ ( innerStringCFML | ESCAPE_SINGLE_QUOTE | ~(SINGLE_QUOTE | ESCAPE_SINGLE_QUOTE | HASH) )* SINGLE_QUOTE
	)
	;

identifier
	:
	IDENTIFIER (struct)? (EOF!)?
	;
	
struct
	:
	OPEN_CURLY codeStatement? CLOSE_CURLY
	;

function 
	:
	('new')? id=IDENTIFIER OPEN_PAREN (argumentStatement)? CLOSE_PAREN
	-> ^(FUNCTION_CALL[$id] OPEN_PAREN (argumentStatement)? CLOSE_PAREN)
	;
	
argumentStatement
	: 
	codeStatement ((COMMA|EQUALS) codeStatement)*
	;

functionDeclaration
	:
	MODIFIER? TYPE? FUNCTION id=IDENTIFIER OPEN_PAREN (argumentDeclaration)? CLOSE_PAREN
	block
	-> ^(FUNCTION FUNCTION_DECLARATION[$id] OPEN_PAREN (argumentDeclaration)? CLOSE_PAREN block)
	;
	
argumentDeclaration
	:
	(argumentType)? IDENTIFIER (EQUALS codeStatement)? (COMMA (argumentType)? IDENTIFIER (EQUALS codeStatement)?)* 
	;

argumentType
  : type -> ^( ARGUMENT_TYPE type)
  ;

type
  : identifier ( DOT ( identifier) )*
  | stringLiteral
  ;

	
functionAttribute
:
IDENTIFIER EQUALS stringLiteral ~(OPEN_CURLY)
;

ifStatement
	:
	IF^ OPEN_PAREN codeStatement CLOSE_PAREN
	block
	(elseifStatement)*
	(elseStatement)?
	;
	
elseifStatement
	:
	ELSE IF OPEN_PAREN codeStatement CLOSE_PAREN	
	block
	-> ^(
		ELSEIF ELSE IF OPEN_PAREN codeStatement CLOSE_PAREN 
		block
	    )
	;
	
elseStatement
	:
	ELSE^
	block
	;

tryStatement
	:
	TRY^
	block
	catchStatement	
	;


catchClass
	:
	IDENTIFIER(DOT IDENTIFIER)*
	;
	
catchStatement
	:
	CATCH OPEN_PAREN catchClass IDENTIFIER CLOSE_PAREN
	block 
	-> ^(CATCH OPEN_PAREN catchClass IDENTIFIER CLOSE_PAREN block)
	;
	

forStatement
	:
	FOR^ OPEN_PAREN (forConditions | forIn) CLOSE_PAREN
	block;
	
forIn
	:
	IDENTIFIER IN cfmlLinking
	;

forConditions
	:
	setStatement
	SEMI_COLON
	setStatement
	SEMI_COLON
	setStatement
	;

whileStatement
	:
	WHILE^ OPEN_PAREN codeStatement CLOSE_PAREN
	block
	;

doWhileStatement
	:
	DO^
	block
	WHILE OPEN_PAREN codeStatement CLOSE_PAREN
	;

block
	:
	(OPEN_CURLY script CLOSE_CURLY) SEMI_COLON?
	|
	(nonBlockStatement)
	;


switchStatement
	:
	SWITCH^ OPEN_PAREN codeStatement CLOSE_PAREN
	OPEN_CURLY
	(caseStatement)*
	(defaultStatement)?
	CLOSE_CURLY
	;
	
caseStatement
	:
	CASE^ (stringLiteral | NUMBER) COLON
	script
	;

defaultStatement
	:
	DEFAULT^ COLON
	script
	;


breakStatement
	:
	BREAK	
	;

/* Lexer */

MODIFIER
    :   'public'
    |   'protected'
    |   'private'
    |   'static'
    |   'abstract'
    |   'final'
    |   'native'
    |   'synchronized'
    |   'transient'
    |   'volatile'
    |   'strictfp'
    ;

TYPE
    :   'void'
    |   'string'
    ;


FUNCTION
	:
	'function'
	;

IF
	:
	'if'
	;

ELSE
	:
	'else'
	;

TRY
	:
	'try'
	;

CATCH
	:
	'catch'
	{
		setMode(CATCH_MODE);
	}
	;
RETURN
	:
	'return'
	;

FOR
	:
	'for'
	;

IN
	:
	'in'
	;

WHILE
	:
	'while'
	;
	
DO
	:
	'do'
	;

NOT	:
	'not' | '!'
	;

EQUALS
	:
	'='
	;

SWITCH
	:
	'switch'
	;

CASE
	:
	'case'
	;

DEFAULT
	:
	'default'
	;
	
BREAK
	:
	'break'
	;

COLON	:
	':'
	;

OPERATOR
	:
	( MATH_OPERATOR | STRING_OPERATOR | CONDITION_OPERATOR | BOOLEAN_OPERATOR )
	;

COMMA	:
	','
	;

SEMI_COLON
	:
	';'
	;
	
HASH	:
	'#'
	;

OPEN_PAREN
	:
	'('
	;

CLOSE_PAREN
	:
	')'
	;

OPEN_SQUARE
	:
	'['
	;

CLOSE_SQUARE
	:
	']'
	;

OPEN_CURLY
	:
	'{'
	;

CLOSE_CURLY
	:
	'}'
	;

DOT
	:
	'.'
	;

VAR
	:
	'var' ~(EQUALS)
	;

NUMBER
	:
	DIGIT+(DOT DIGIT+)?
	;

ESCAPE_DOUBLE_QUOTE
	:
	'""'
	;
	
ESCAPE_SINGLE_QUOTE
	:
	'\'\''
	;

DOUBLE_QUOTE
	:
	'"'
	;
SINGLE_QUOTE
	:
	'\''
	;

IDENTIFIER
	:
	(LETTER | UNDERSCORE )(LETTER | DIGIT | UNDERSCORE )*	
	;

/*
EXCEPTIONNAME
	:
	{ getMode() == CATCH_MODE }?
	(LETTER | DIGIT | UNDERSCORE)(DOT | LETTER | DIGIT | UNDERSCORE)*
	{
		setMode(NORMAL_MODE);
	}
	;
*/
/* fragments */

fragment MATH_OPERATOR
	:
	('+' | '*' | '\/' | '\\' | '^' | 'mod' | '-')
	;
fragment STRING_OPERATOR
	:
	'&'
	;
fragment CONDITION_OPERATOR
	:
	('eq'|'neq'|'is'|'gt'|'lt'|'lte'|'gte'|'=='|'!=')
	;

fragment BOOLEAN_OPERATOR
	:
	('or'|'and'|'xor'|'eqv'|'imp'|'&&'|'||')
	;

fragment UNDERSCORE
	:
	'_'
	;

fragment DIGIT
	:
	'0'..'9'
	;

fragment LETTER
	:
	'a'..'z' | 'A'..'Z' | '$'
	;

/* hidden tokens */

WS : (' '|'\t'|'\n')+ {$channel=HIDDEN;};

COMMENT
	:   
	'/*' ( options {greedy=false;} : . )* '*/' 
	{
		$channel=COMMENT_CHANNEL; //90 is the comment channel
	}
	;

LINE_COMMENT
	: 
	'//' ~('\n'|'\r')* '\r'? '\n' 
	{
		$channel=COMMENT_CHANNEL; //90 is the comment channel
	}
	;

OTHER
	:
	(options {greedy=false;} : . )
	;
