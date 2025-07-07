"
Just because one task for the BPAgent involved finding a bug in the Compiler...
"
Class {
	#name : #OriginalCompiler,
	#superclass : #Compiler,
	#category : #BPAgent,
	#'squeak_changestamp' : 'ct 7/7/2025 21:00'
}

{
	#category : #compiling,
	#'squeak_changestamp' : 'ct 7/7/2025 18:16'
}
OriginalCompiler class >> newParser [

	^ OriginalParser new
]

{
	#category : #accessing,
	#'squeak_changestamp' : 'ct 7/7/2025 19:13'
}
OriginalCompiler class >> parserClass [

	^ OriginalParser
]

{
	#category : #'public access',
	#'squeak_changestamp' : 'ct 7/7/2025 18:15'
}
OriginalCompiler >> parser [

	parser ifNil: [parser := OriginalParser new].
	^parser
]
