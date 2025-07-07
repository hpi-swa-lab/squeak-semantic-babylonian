Class {
	#name : #BPAgent,
	#superclass : #SemanticAgent,
	#instVars : [
		'object',
		'lastTrace',
		'previousMethods'
	],
	#category : #BPAgent
}

{
	#category : #functions,
	#'squeak_changestamp' : 'ct 7/7/2025 17:46'
}
BPAgent >> browseClass: className [
	"get the definition, comment, and all method names ('selectors') of the class"
	<function: browseClass(className: string)>

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
	#'squeak_changestamp' : 'ct 7/7/2025 17:46'
}
BPAgent >> browseClass: className selector: selectorString [
	"get the full source code of the method className>>selector"
	<function: browseMethod(
		className: string "e.g., ""Object"" or ""Object class"" (for static class-side methods)",
		selector: string "e.g., ""copy"", ""at:put:"", or ""="""
	)>

	| class selector |
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
	#'squeak_changestamp' : 'ct 7/7/2025 17:49'
}
BPAgent >> browseImplementors: selectorString [
	"get a list of methods in the system that implement this selector."
	<function: browseImplementors(
		selector: string
	)>

	| longSize detailSize selector senders detailSample sample |
	longSize := 20.
	detailSize := 10.
	
	selector := selectorString.
	(selector beginsWith: '#') ifTrue: [selector := selector allButFirst].
	selector := selector asSymbol.
	
	senders := self systemNavigation allImplementorsOf: selector.
	sample := self rankSenders: senders forQuery: nil take: longSize.
	
	detailSample := sample take: detailSize.
	sample := sample allButFirst: detailSample size.
	
	^ OrderedJsonObject new
		sampleImplementors:
			(detailSample collect: [:method | self sourceForClass: method actualClass selector: method selector]);
		moreSampleImplementors:
			(sample collect: [:method | method sesqName]);
		yourself
]

{
	#category : #functions,
	#'squeak_changestamp' : 'ct 7/7/2025 17:46'
}
BPAgent >> browsePackage: packageName [
	"get all classes in the package"
	<function: browsePackage(packageName: string)>

	| package |
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
	#'squeak_changestamp' : 'ct 7/7/2025 17:47'
}
BPAgent >> browseSenders: selectorString [
	"get a list of methods in the system that use this selector (i.e., call a method with that name). useful to find examples that teach you how you can invoke a method."
	<function: browseSenders(
		selector: string
	)>

	| longSize detailSize selector senders detailSample sample |
	longSize := 20.
	detailSize := 10.
	
	selector := selectorString.
	(selector beginsWith: '#') ifTrue: [selector := selector allButFirst].
	selector := selector asSymbol.
	
	senders := self systemNavigation allCallsOn: selector.
	sample := self rankSenders: senders forQuery: nil take: longSize.
	
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
	#'squeak_changestamp' : 'ct 7/7/2025 17:56'
}
BPAgent >> getTracedValues [
	"Get all traced values from the last evaluated expression."
	<function: getTracedExpressions()>

	^ lastTrace generateOutput
]

{
	#category : #'initialize-release',
	#'squeak_changestamp' : 'ct 7/7/2025 19:22'
}
BPAgent >> initialize [

	super initialize.
	previousMethods := OrderedCollection new.
]

{
	#category : #conversation,
	#'squeak_changestamp' : 'ct 7/7/2025 21:38'
}
BPAgent >> initializeConversation: aConversation [

	super initializeConversation: aConversation.
	
	aConversation withConfigDo: [:config | config temperature: 0.4].
	aConversation addSystemMessage: 'You are an autonomous agent which gets a "why does this not work question" by a programmer and automatically answers this question by finding the cause of a problem. For this, you work highly autonomically by developing possible hypotheses, trying to validate or falsify them by reading and changing the source code, and iterating until you can answer the original question.

You are operating in an interactive Squeak/Smalltalk system.

Your workflow looks like this:
0. You get a question by the programmer, which includes a way to reproduce their problem/observation.
1. You reproduce the problem/observation.
2. Repeat until done:
2.1. Develop possible hypotheses that spawn subquestions (e.g., it could be that this subsystem is wrong, that X was forgotten, that Y is buggy)
2.2. Experimentally test these hypotheses and answer your subquestions by interacting with the programming system through tools. Your central mechanism for interacting with the system are different empirical tools, which you can use to access source code, instrument it with additional tracing code, and run code examples (see below).
2.3. Evaluate these hypotheses based on your findings. Until you are done, generate new hypotheses and repeat 2.
3. If you have found the problem that answers the original question, report your findings and experiments you ran to the user and exit.
	Note that if you propose a fix, you should also test and confirm it before completing your reply.

Available tools:
- Code browsing: Browse code in the image by calling browsePackage(), browseClass(), browseMethod(), browseSenders(), and browseImplementors().
- Tracing: Trace any expression inside any methods by recompiling (aka instrumenting) them with additional code to record the value of any nodes in the AST.
	For example, given this method:
		foo: arg
			bar := self doSomethingWith: arg.
			(self testSometing: bar)
				ifTrue: [^ bar plonk].
			self griffle: bar.
			^ bar plonkWith: self
	You can instrument this method like this:
		foo: arg
			bar := ((self bpTraceWithId: 1) doSomethingWith: (arg bpTraceWithId: 2)) bpTraceWithId: 3.
			(self testSometing: bar)
				ifTrue: [^ (bar plonk) bpTraceWithId: 4].
			self griffle: bar.
			^ (bar plonkWith: self) bpTraceWithId: 5
	For instrumentation, you need to call browseMethod() first to get the source code, then call recompile() to decorate it with inserted (... bpTraceWithId: <id>) expressions that wrap existing expressions anywhere in the AST. You MUST make up unique IDs for every tracing expression in the system! DO NOT FORGET to wrap the decorated expression into brackets, e.g. `a ifTrue: [b]` to `((a bpTraceWithId: 1) ifTrue: [(b bpTraceWithId: 2)]) bpTraceWithId: 3`!
	You can then run examples via eval().
	After that, you can retrieve the traced values by calling getTracedValues().
- Running code: You can run any tests/examples by calling eval() with a short expression (do-it) or script.

You MUST think out aloud and process the above workflow.
You MUST only answer to the user when you have constructed and empirically confirmed a hypotheses by calling tools. DO NOT tell the user what they should try out - try it our by yourself.
Remember that you have live access to the system and use it. The use of instrumentation via recompile() + getTracedValues() is essential for successful investigation in most cases.'.
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
	#'squeak_changestamp' : 'ct 7/7/2025 17:47'
}
BPAgent >> orderedFunctionNames [

	^ #(browsePackage: browseClass: browseClass:selector: browseSenders:)
]

{
	#category : #private,
	#'squeak_changestamp' : 'ct 7/7/2025 17:47'
}
BPAgent >> rankSenders: senders forQuery: queryOrNil take: anInteger [

	| corpus |
	corpus := SesqMethodCorpus instance.
	corpus ifNil:
		[^ (senders semanticRandomSample: anInteger * 10) withoutDuplicates take: anInteger].
	^ corpus
		rankObjects: senders
		clusteredSampleForQuery: queryOrNil
		take: anInteger
]

{
	#category : #functions,
	#'squeak_changestamp' : 'ct 7/7/2025 20:35'
}
BPAgent >> recompile: className source: sourceString [
	"..."
	<function: recompile "Recompile a method in the system with changed source code, e.g., after decorating it with tracing.
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
	previousMethods addLast: ((class changeRecordsAt: selector) ifNotNil: [:records | records first] ifNil: [MethodReference class: class selector: selector]).
	
	selector := class compile: source.
	^ 'Successfully recompiled {1}>>{2}' format: {class. selector}
]

{
	#category : #'as yet unclassified',
	#'squeak_changestamp' : 'ct 7/7/2025 19:27'
}
BPAgent >> restorePreviousMethods [

	previousMethods removeAllSuchThat: [:method |
		(method isKindOf: ChangeRecord)
			ifTrue: [method fileIn]
			ifFalse: [method actualClass removeSelector: method selector].
		true]
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
	#'squeak_changestamp' : 'ct 7/7/2025 17:47'
}
BPAgent >> sourceForClass: aClass selector: selector [

	| source |
	source := (aClass sourceCodeAt: selector ifAbsent: [self error: ('Class {1} has no method {2}' format: {aClass name. selector printString})])
		truncateWithEllipsisTo: 6000.
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
