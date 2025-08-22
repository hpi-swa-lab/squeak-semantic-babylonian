Extension { #name : #Object }

{
	#category : #'*BPAgent-tracing',
	#'squeak_changestamp' : 'ct 7/7/2025 17:20'
}
Object >> bpTraceWithId: id [

	BPTracer current ifNotNil: [:tracer |
		tracer trace: self withId: id from: thisContext sender].
	^ self
]
