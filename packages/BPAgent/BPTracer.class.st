Class {
	#name : #BPTracer,
	#superclass : #Object,
	#instVars : [
		'methods',
		'values'
	],
	#classVars : [
		'Current'
	],
	#category : #BPAgent
}

{
	#category : #accessing,
	#'squeak_changestamp' : 'ct 7/7/2025 17:21'
}
BPTracer class >> current [

	^ Current
]

{
	#category : #accessing,
	#'squeak_changestamp' : 'ct 7/7/2025 18:36'
}
BPTracer class >> current: aTracerOrNil [

	Current := aTracerOrNil.
]

{
	#category : #accessing,
	#'squeak_changestamp' : 'ct 7/7/2025 17:23'
}
BPTracer class >> current: aTracer during: aBlock [

	| previous |
	previous := self current.
	Current := aTracer.
	^ aBlock ensure:
		[Current := previous]
]

{
	#category : #tracing,
	#'squeak_changestamp' : 'ct 7/7/2025 20:23'
}
BPTracer class >> disableTracingDuring: aBlock [

	^ self current: nil during: aBlock
]

{
	#category : #'as yet unclassified',
	#'squeak_changestamp' : 'ct 7/7/2025 17:21'
}
BPTracer class >> test [

	| x y |
	x := 1 bpTraceWithId: 1.
	y := 2 bpTraceWithId: 2.
	^ (x + y) bpTraceWithId: 3
]

{
	#category : #tracing,
	#'squeak_changestamp' : 'ct 7/7/2025 17:22'
}
BPTracer class >> trace: aBlock [

	| tracer |
	tracer := self new.
	self current: tracer during: aBlock.
	^ tracer
]

{
	#category : #accessing,
	#'squeak_changestamp' : 'ct 7/7/2025 20:22'
}
BPTracer >> generateOutput [

	| regex |
	regex := 'bpTraceWithId\: (\d+|''[^'']*'')' asRegex.
	^ String streamContents: [:stream |
		(methods values asSet sorted: [:method | method methodClass name] ascending , [:method | method selector name]) do: [:method | | decoratedSource source |
			source := method getSource asString.
			decoratedSource := source copyWithRegex: regex matchesTranslatedUsing: [:match |
				values
					at: (BPTracer disableTracingDuring: [OriginalCompiler evaluate: (regex subexpression: 2)])
					ifPresent: [:thisValues |
						match , ' "-> ' ,
							(thisValues collect: [:ea |
								| s |
								s := ea printString.
								(s includesSubstring: ea class theNonMetaClassName) ifFalse: [s := 'a ' , ea class name , ': ' , s].
								s])
									asCommaString , '" ']
					ifAbsent: [match]].
			stream nextPutAll: method class name , '>>' , decoratedSource; cr; cr]]
]

{
	#category : #'initialize-release',
	#'squeak_changestamp' : 'ct 7/7/2025 17:29'
}
BPTracer >> initialize [

	super initialize.
	methods := Dictionary new.
	values := Dictionary new.
]

{
	#category : #accessing,
	#'squeak_changestamp' : 'ct 7/7/2025 17:29'
}
BPTracer >> trace: value withId: id from: aContext [

	| method |
	method := aContext homeMethod.
	methods at: id ifPresent: [:existingMethod | existingMethod = method ifFalse: [self error: 'This trace id is already used for another method: ' , existingMethod]] ifAbsentPut: [method].
	(values at: id ifAbsentPut: OrderedCollection new)
		addLast: value.
]
