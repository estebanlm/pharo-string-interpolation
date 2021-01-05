Class {
	#name : #BaselineOfStringInterpolation,
	#superclass : #BaselineOf,
	#category : #BaselineOfStringInterpolation
}

{ #category : #baselines }
BaselineOfStringInterpolation >> baseline: spec [
	<baseline>
	
	spec for: #common do: [ 
		spec package: 'StringInterpolation' ]
]
