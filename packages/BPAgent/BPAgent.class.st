Class {
	#name : #BPAgent,
	#superclass : #SemanticAgent,
	#instVars : [
		'object',
		'lastTrace',
		'previousMethods',
		'browsesSinceLastLog',
		'knownMethods'
	],
	#category : #BPAgent
}

{
	#category : #functions,
	#'squeak_changestamp' : 'ct 7/8/2025 20:39'
}
BPAgent >> browseClass: className [
	"get the definition, comment, and all method names ('selectors') of the class"
	<function: browseClass(className: string)>

	self incrementAndCheckBrowsingCounter.
	
	^ self browseClass: className meta: false
]

{
	#category : #functions,
	#'squeak_changestamp' : 'ct 7/7/2025 17:46'
}
BPAgent >> browseClass: className meta: isMeta [

	| class organizer |
	class := (self environment classNamed: className)
		ifNil: [self error: 'unknown class'].
	organizer := class organization.
	
	^ CurrentReadOnlySourceFiles cacheDuring: 
		[OrderedJsonObject new
			className: class name;
			definition: class definition asString withUnixLineEndings;
			comment: (class comment truncateWithEllipsisTo: 3000) asString withUnixLineEndings;
			categorizedSelectors:
				(organizer sesqSortedCategorizedElements collect: [:selectors |
					selectors collect: #printString]);
			in: [:result |
				isMeta ifFalse:
					[result superclass:
						(class superclass ifNotNil: [:superclass |
							superclass = Object
								ifFalse:
									[(self browseClass: superclass name)]
								ifTrue:
									[OrderedJsonObject new
										className: superclass name;
										yourself]]).
					result classSide:
						((self browseClass: class class name meta: true)
							removeKey: #comment;
							yourself)]];
			yourself]
]

{
	#category : #functions,
	#'squeak_changestamp' : 'ct 7/8/2025 19:08'
}
BPAgent >> browseClass: className selector: selectorString [
	"get the full source code of the method className>>selector"
	<function: browseMethod(
		className: string "e.g., ""Object"" or ""Object class"" (for static class-side methods)",
		selector: string "e.g., ""copy"", ""at:put:"", or ""="""
	)>

	| class selector |
	self incrementAndCheckBrowsingCounter.
	
	class := (self environment classNamed: className)
		ifNil: [self error: 'unknown class'].
	selector := selectorString.
	(selector beginsWith: '#') ifTrue: [selector := selector allButFirst].
	selector := selector asSymbol.
	
	(class whichSuperclassSatisfies: [:superclass | superclass includesSelector: selector])
		ifNotNil: [:superclass |
			class := superclass].
	
	^ self sourceForClass: class selector: selector
]

{
	#category : #functions,
	#'squeak_changestamp' : 'ct 8/22/2025 19:31'
}
BPAgent >> browseImplementors: selectorString [
	"get a list of methods in the system that implement this selector."
	<function: browseImplementors(
		selector: string
	)>

	| longSize detailSize selector implementors detailSample sample moreSample |
	self incrementAndCheckBrowsingCounter.
	
	longSize := 20.
	detailSize := 10.
	
	selector := selectorString.
	(selector beginsWith: '#') ifTrue: [selector := selector allButFirst].
	selector := selector asSymbol.
	
	implementors := self systemNavigation allImplementorsOf: selector.
	sample := self sampleMethods: implementors take: longSize.
	
	sample ifEmpty: [^ 'no implementors'].
	
	detailSample := sample take: detailSize.
	moreSample := sample allButFirst: detailSample size.
	
	moreSample ifEmpty: [^ OrderedJsonObject new implementors: (detailSample collect: [:method | self sourceForClass: method actualClass selector: method selector]); yourself].
	
	^ OrderedJsonObject new
		sampleImplementors:
			(detailSample collect: [:method | self sourceForClass: method actualClass selector: method selector]);
		moreSampleImplementors:
			(moreSample collect: [:method | method sesqName]);
		yourself
]

{
	#category : #functions,
	#'squeak_changestamp' : 'ct 7/8/2025 19:08'
}
BPAgent >> browsePackage: packageName [
	"get all classes in the package"
	<function: browsePackage(packageName: string)>

	| package |
	self incrementAndCheckBrowsingCounter.
	
	package := self environment packageOrganizer
		packageNamed: packageName
		ifAbsent: [self error: 'unknown package'].
	
	^ OrderedJsonObject new
		packageName: package name;
		classHierarchy:
			(String streamContents: [:stream |
				(package classes groupBy: #category) withKeysSorted
					associations
						do: [:categoryAndClasses |
							stream
								nextPut: $";
								nextPutAll: categoryAndClasses key;
								nextPut: $";
								cr.
							(Browser new
								selectSystemCategory: categoryAndClasses key;
								hierarchicalClassList)
									do: [:line |
										stream
											nextPutAll: line;
											cr]]
									separatedBy: [stream cr]]) withUnixLineEndings;
		yourself
]

{
	#category : #functions,
	#'squeak_changestamp' : 'ct 8/22/2025 19:31'
}
BPAgent >> browseSenders: selectorString [
	"get a list of methods in the system that use this selector (i.e., call a method with that name). useful to find examples that teach you how you can invoke a method."
	<function: browseSenders(
		selector: string
	)>

	| longSize detailSize selector senders detailSample sample |
	self incrementAndCheckBrowsingCounter.
	
	longSize := 20.
	detailSize := 10.
	
	selector := selectorString.
	(selector beginsWith: '#') ifTrue: [selector := selector allButFirst].
	selector := selector asSymbol.
	
	senders := self systemNavigation allCallsOn: selector.
	sample := self sampleMethods: senders take: longSize.
	
	detailSample := sample take: detailSize.
	sample := sample allButFirst: detailSample size.
	
	^ OrderedJsonObject new
		sampleSenders:
			(detailSample collect: [:method | self sourceForClass: method actualClass selector: method selector]);
		moreSampleSenders:
			(sample collect: [:method | method sesqName]);
		yourself
]

{
	#category : #functions,
	#'squeak_changestamp' : 'ct 7/7/2025 17:47'
}
BPAgent >> eval: aString [
	"evaluate a Smalltalk expression (aka 'do it'). Note that all temporary variables from the expression are local to this evaluation and cannot be accessed again in later expressions."
	<function: eval(expression: string)>

	| printString result |
	result := self
		tryEval: aString
		withErrorDo: [:ex |
			^ self serializeExceptionVerbosely: ex].
	[printString := result printString]
		on: Error do: [:ex |
			^ OrderedJsonObject new
				note: 'Expression evaluated successfully, but could not print the result.';
				resultClass: result class printString;
				printStringError: (self serializeException: ex);
				yourself].
	^ JsonObject new
		result: printString;
		yourself
]

{
	#category : #functions,
	#'squeak_changestamp' : 'ct 7/8/2025 19:09'
}
BPAgent >> evalWithLogs: aString [
	"evaluate a Smalltalk expression and record during the execution. Returns all logged expressions."
	<function: evalWithLogs(expression: string)>

	| result |
	lastTrace := nil.
	result := self
		tryEval: aString
		withErrorDo: [:ex |
			^ self serializeExceptionVerbosely: ex].
	self resetBrowsingCounter.
	^ lastTrace generateOutput
]

{
	#category : #private,
	#'squeak_changestamp' : 'ct 7/8/2025 20:41'
}
BPAgent >> incrementAndCheckBrowsingCounter [

	(browsesSinceLastLog := browsesSinceLastLog + 1) >= 5 ifTrue:
		[self error: 'No more browsing allowed, you must first log runtime data from the previous methods by calling `recompileWithLogs()` and then `evalWithLogs()`!'].
]

{
	#category : #'initialize-release',
	#'squeak_changestamp' : 'ct 7/8/2025 19:36'
}
BPAgent >> initialize [

	super initialize.
	previousMethods := OrderedCollection new.
	browsesSinceLastLog := 0.
	knownMethods := Set new.
]

{
	#category : #conversation,
	#'squeak_changestamp' : 'ct 7/8/2025 19:55'
}
BPAgent >> initializeConversation: aConversation [

	super initializeConversation: aConversation.
	
	aConversation withConfigDo: [:config | config temperature: 0.4].
	aConversation addSystemMessage: 'You are an autonomous agent which answer questions about runtime behavior of a program. Typical questions are "Why was this method invoked" or "Where does this value come from". You answer these questions by directly interacting with the runtime system. First, you can BROWSE the source code of classes and methods. Second, you can insert LOGGING statements into any methods and RUN examples to gather runtime values and thus improve your understanding code.

You are operating in an interactive Squeak/Smalltalk system where you have direct access to the runtime. You should take advantage of this context and use interactive functions a lot. DO NOT only read static source code and try to reason what it does, but DO regularly seek evidence by using logging statements and rerunning.

You must adhere to the following iterative workflow:
0. You get a question by the programmer, which includes a way to reproduce their observation ("example").
1. You reproduce the observation by RUNNING the example (via the `eval()` function).
2. Iteratively repeat until done:
2.1. BROWSE one or a few relevant methods to retrieve more context about the problem (via `browseMethod()` & Co.). You MUST NOT browse more than 5 methods before going to 2.2 (LOGGING).
2.2. LOG values from relevant methods and RERUN an example to get runtime context about the source code (via `recompileWithLogs()` + `evalWithLogs()`). For this, you may ask subordinate questions first to clarify what you need to know (e.g., what value does this variable hold, which branch in this method is taken, what method will be invoked here). Make sure to ask yourself these questions OFTEN and ALWAYS answering them through logging + rerunning!
2.3. Evaluate the results from your logs to answer your subordinate questions. Until you are done, generate new questions and repeat 2.
3. If you have found a full answer to the original question of the user, report your findings and experiments you ran to the user and exit. Do not terminate before you have found a full answer/explanation for their question.
	Note that if you propose a fix, you should also test and confirm it before completing your reply.

Available tools:
- Code BROWSING: Browse code in the image by calling `browsePackage()`, `browseClass()`, `browseMethod()`, `browseSenders()`, or `browseImplementors()`.
- LOGGING: Log any expressions inside any methods by recompiling them with additional inserted logging statements. These logging states are placed as wrappers around any nodes in the AST to record their runtime values.
	For example, given this method:
		```smalltalk
		foo: arg
			bar := self doSomethingWith: arg.
			(self testSometing: bar)
				ifTrue: [^ bar plonk].
			self griffle: bar.
			^ bar plonkWith: self
		```
	You can recompile this method like this with added logging statements:
		```smalltalk
		foo: arg
			bar := ((self bpTraceWithId: 1) doSomethingWith: (arg bpTraceWithId: 2)) bpTraceWithId: 3.
			(self testSometing: bar)
				ifTrue: [^ (bar plonk) bpTraceWithId: 4].
			self griffle: bar.
			^ (bar plonkWith: self) bpTraceWithId: 5
		```
	For logging, you need to have browsed the method before to know its source code. Then call `recompileWithLogs()` to decorate it with inserted (... bpTraceWithId: <id>) expressions that wrap existing expressions anywhere in the AST. You MUST make up unique IDs for every tracing expression in the system! DO NOT FORGET to wrap the decorated expression into brackets, e.g. `a ifTrue: [b]` to `((a bpTraceWithId: 1) ifTrue: [(b bpTraceWithId: 2)]) bpTraceWithId: 3`!
	Finally, after recompiling rerun any example via `evalWithLogs()`.
- RUNNING code: You can run any tests/examples by calling `eval()` with a short expression (do-it) or script.

You MUST think out aloud and process the above workflow.
You MUST only answer to the user when you have constructed and empirically confirmed a complete hypotheses by calling tools. DO NOT tell the user what they should try out - try it our by yourself.
DO NOT GUESS anything about the actual behavior of the code - whenever something is unclear (such as which code was executed), **ALWAYS USE LOGGING (`recompileWithLogs()` + `evalWithLogs()`)** to empirically validate your assumptions.'.
]

{
	#category : #private,
	#'squeak_changestamp' : 'ct 7/7/2025 17:47'
}
BPAgent >> object [

	^ nil
]

{
	#category : #functions,
	#'squeak_changestamp' : 'ct 7/8/2025 18:58'
}
BPAgent >> orderedFunctionNames [

	^ #(browsePackage: browseClass: browseClass:selector: browseSenders: eval: recompile:source: evalWithLogs:)
]

{
	#category : #functions,
	#'squeak_changestamp' : 'ct 7/8/2025 20:14'
}
BPAgent >> recompile: className source: sourceString [
	"..."
	<function: recompileWithLogs "recompile a method in the system with source code that is decorated with logging expressions.
		Example: recompile(""MyClass"", ""foo: arg ^ (arg plonk) bpTraceWithId: 42"")"
	(
		className: string,
		source: string
	)>

	| class selector source |
	class := (self environment classNamed: className)
		ifNil: [self error: 'unknown class'].
	source := sourceString withSqueakLineEndings.
	(source beginsWith: className , '>>') ifTrue: [source := source allButFirst: (className , '>>') size].
	(source beginsWith: className , ' >> ') ifTrue: [source := source allButFirst: (className , ' >> ') size].
	selector := class newParser parseSelector: source.
	class methodDict
		at: selector
		ifPresent: [:method | (knownMethods includes: method) ifFalse: [browsesSinceLastLog := 3. self error: 'You cannot recompile a method before have browsed it. You may browse it now. You have one new browse operation left.']]
		ifAbsent: [browsesSinceLastLog := 3. self error: 'This method does not exist, so you cannot recompile it. You have one new browse operation left.'].
	previousMethods addFirst: ((class changeRecordsAt: selector) ifNotNil: [:records | records first -> (class >> selector)] ifNil: [MethodReference class: class selector: selector]).
	
	selector := self withAgentAuthorInitialsDo: [class compile: source].
	knownMethods add: class >> selector.
	^ 'Successfully recompiled {1}>>{2}' format: {class. selector}
]

{
	#category : #private,
	#'squeak_changestamp' : 'ct 7/8/2025 19:11'
}
BPAgent >> resetBrowsingCounter [

	browsesSinceLastLog := 0.
]

{
	#category : #functions,
	#'squeak_changestamp' : 'ct 7/8/2025 20:31'
}
BPAgent >> restorePreviousMethods [
	<function: resetAllMethods "as a last resort, revert all changed methods when something is broken. Note that this does NOT reset the browsing limit."()>

	previousMethods removeAllSuchThat: [:method |
		(method isKindOf: Association)
			ifTrue: [[method key fileIn] ifError: ["self halt." method value methodClass methodDict at: method value selector put: method value]]
			ifFalse: [method actualClass removeSelector: method selector].
		true]
]

{
	#category : #private,
	#'squeak_changestamp' : 'ct 8/22/2025 19:30'
}
BPAgent >> sampleMethods: methods take: anInteger [

	methods ifEmpty: [^ #()].
	^ (methods semanticRandomSample: anInteger * 10) withoutDuplicates take: anInteger
]

{
	#category : #'function calling',
	#'squeak_changestamp' : 'ct 7/7/2025 17:46'
}
BPAgent >> serializeError: anException [

	^ JsonObject new
		at: #error put: (self serializeException: anException);
		yourself
]

{
	#category : #private,
	#'squeak_changestamp' : 'ct 7/7/2025 17:47'
}
BPAgent >> serializeException: anException [

	^ OrderedJsonObject new
		description: anException description;
		stack:
			((anException signalerContext stack copyUpTo: anException privHandlerContext) allButLast
				collect: #asString);
		yourself
]

{
	#category : #private,
	#'squeak_changestamp' : 'ct 7/7/2025 17:47'
}
BPAgent >> serializeExceptionVerbosely: anException [

	^ OrderedJsonObject new
		at: #error put: (self serializeException: anException);
		in: [:response |
			((anException isKindOf: MessageNotUnderstood) "and: [anException signalerContext sender selector isDoIt]") ifTrue:
				[response note: 'A common source of MessageNotUnderstood errors is that some brackets were missed to separate messages from each other. E.g., `myArray select: [:x | x notNil] collect: [:x | x customer]` must be corrected to `(myArray select: [:x | x notNil]) collect: [:x | x customer]`, and `myArray select: [:x | x notNil] , otherArray` must be corrected to `(myArray select: [:x | x notNil]) , otherArray`.']];
		yourself
]

{
	#category : #private,
	#'squeak_changestamp' : 'ct 7/8/2025 19:37'
}
BPAgent >> sourceForClass: aClass selector: selector [

	| source |
	source := (aClass sourceCodeAt: selector ifAbsent: [self error: ('Class {1} has no method {2}' format: {aClass name. selector printString})])
		truncateWithEllipsisTo: 6000.
	knownMethods add: aClass >> selector.
	^ aClass name , '>>' , source asString withUnixLineEndings
]

{
	#category : #private,
	#'squeak_changestamp' : 'ct 7/7/2025 17:47'
}
BPAgent >> tryEval: aString withErrorDo: errorBlock [

	^ self tryEval: aString withResultDo: [:result | ^ result] withErrorDo: errorBlock
]

{
	#category : #private,
	#'squeak_changestamp' : 'ct 7/7/2025 20:30'
}
BPAgent >> tryEval: aString withResultDo: resultBlock withErrorDo: errorBlock [

	|  method result |
	[| methodNode |
	methodNode := OriginalCompiler new compileCue: (CompilationCue source: aString context: nil receiver: self object class: self object class environment: self object class environment requestor: nil) noPattern: true ifFail: [nil].
	method := methodNode generateWithTempNames]
		on: Error , Warning , Halt do: [:ex |
			^ errorBlock value: ex].
	lastTrace := BPTracer trace:
		[[[result := self object withArgs: #() executeMethod: method]
			valueWithin: 5 seconds onTimeout: [self error: 'timeout']]
				on: Error , Warning , Halt do: [:ex |
					^ errorBlock value: ex]].
	^ resultBlock value: result
]

{
	#category : #private,
	#'squeak_changestamp' : 'ct 7/8/2025 20:07'
}
BPAgent >> withAgentAuthorInitialsDo: aBlock [

	^ Utilities useAuthorInitials: 'agent' during: aBlock
]
