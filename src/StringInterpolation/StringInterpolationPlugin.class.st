Class {
	#name : #StringInterpolationPlugin,
	#superclass : #OCCompilerASTPlugin,
	#instVars : [
		'ast'
	],
	#category : #StringInterpolation
}

{ #category : #testing }
StringInterpolationPlugin class >> hasInterpolationPattern: aString [ 
	| stream char escape open |
	
	"Any string with a [] pair is a potential interpolation target"
	"^ aString matchesRegex: '.*\[.*\].*'"
	stream := aString readStream.
	open := false.
	escape := false.
	[ stream atEnd ] whileFalse: [ 
		char := stream next.
		(char = $\) ifTrue: [ escape := escape not ].
		((char = $[) and: [ escape not ]) ifTrue: [ open := true ].
		((char = $]) and: [ escape not and: [ open ] ]) 
			ifTrue: [ ^ true ] ].
	
	^ false
]

{ #category : #api }
StringInterpolationPlugin class >> interpolate: aString withAssociations: aCollection [
	| dictionaryValues |

	dictionaryValues := aCollection asDictionary.
	^ aString class new: aString size streamContents: [ :result | | stream |
		stream := aString readStream.
		[ stream atEnd ] whileFalse: [ | currentChar |
			(currentChar := stream next) == $[
				ifTrue: [ | expression |
					expression := stream upTo: $].
					result nextPutAll: (dictionaryValues at: expression) asString ]
				ifFalse: [
					currentChar == $\
						ifTrue: [ stream atEnd ifFalse: [ result nextPut: stream next ] ]
						ifFalse: [ result nextPut: currentChar ] ] ] ]
]

{ #category : #accessing }
StringInterpolationPlugin class >> priority [

	^ 100
]

{ #category : #'instance creation' }
StringInterpolationPlugin class >> transform: ast [

	^ self new transform: ast
]

{ #category : #transforming }
StringInterpolationPlugin >> expandStringLiteral: aRBLiteralValueNode [ 
	| newMessageNode |
	
	(self hasInterpolationPattern: aRBLiteralValueNode value)
		ifFalse: [ ^ self ].

	newMessageNode := 	RBMessageNode
		receiver: (RBVariableNode named: StringInterpolationPlugin name)
		selector: #interpolate:withAssociations:
		arguments: {
			RBLiteralValueNode value: aRBLiteralValueNode value.
			RBArrayNode statements: (self extractStatementsFrom: aRBLiteralValueNode)}.
	
	aRBLiteralValueNode replaceWith: newMessageNode
]

{ #category : #extracting }
StringInterpolationPlugin >> extractStatementsFrom: aLiteralValueNode [
	"Parses a string inside a literalValueNode and returns a collection of Message sends.
	The receiver of each message send is a string, with the same value as the interpolation pattern.
	The selector is #-> to create an association.
	The argument is an expression to evaluate to a value in the method."
	| messages stream stringToInterpolate |
	messages := OrderedCollection new.

	stringToInterpolate := aLiteralValueNode value.
	stream := stringToInterpolate readStream.
	[ stream atEnd ] whileFalse: [ | currentChar |
		(currentChar := stream next) == $[
			ifTrue: [ | expression expressionPosition |
				expressionPosition := stream position.
				expression := stream upTo: $].
				messages add: (RBMessageNode
					receiver: (RBLiteralNode value: expression)
					selector: #->
					arguments: { [RBParser parseExpression: expression]
						on: SyntaxErrorNotification
						do: [ SyntaxErrorNotification
							inClass: Object
							withCode: ast sourceCode
							doitFlag: false
							errorMessage: 'Invalid syntax in pattern'
							location: expressionPosition + aLiteralValueNode start ] }) ]
			ifFalse: [
				currentChar == $\
					ifTrue: [ stream atEnd ifFalse: [ stream next ] ] ] ].
	^ messages
]

{ #category : #testing }
StringInterpolationPlugin >> hasInterpolationPattern: aString [

	^ self class hasInterpolationPattern: aString
]

{ #category : #accessing }
StringInterpolationPlugin >> priority [

	^ self class priority
]

{ #category : #transforming }
StringInterpolationPlugin >> transform [

	ast nodesDo: [ :each |
		(each isLiteralNode and: [ each value isString ])
			ifTrue: [ self expandStringLiteral: each ]  ].

	^ ast
		doSemanticAnalysis;
		yourself
]

{ #category : #transforming }
StringInterpolationPlugin >> transform: anRBMethodNode [

	ast := anRBMethodNode.
	self transform.
	^ ast
]
