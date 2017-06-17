# ecs [![Build Status](https://travis-ci.org/yglukhov/ecs.svg?branch=master)](https://travis-ci.org/yglukhov/ecs)
Entity Component System, designed to be data oriented. [More info on Wikipedia](https://en.wikipedia.org/wiki/Entity–component–system).

## Usage
```nim
import ecs

type
    MyComponent1 = object
        x, y: int
    MyComponent2 = object
        multiplicationResult: int

let w = newWorld()
let e1 = w.newEntity()
let e2 = w.newEntity()
let e3 = w.newEntity()
let e4 = w.newEntity()

e1.addComponent(MyComponent1(x: 3, y: 5))
e1.addComponent(MyComponent2())

e3.addComponent(MyComponent1(x: 1, y: 1))

e4.addComponent(MyComponent1(x: 5, y: 2))
e4.addComponent(MyComponent2())

e2.addComponent(MyComponent1(x: 2, y: 6))
e2.addComponent(MyComponent2())

w.prepareForProcessing()

var processedEntities = 0

proc process(c: MyComponent1, res: var MyComponent2) {.inline.} =
    ## This proc is basically the System
    res.multiplicationResult = c.x * c.y
    inc processedEntities

w.forEveryMatchingEntity(process)

doAssert(processedEntities == 3)
doAssert(e1.getComponentPtr(MyComponent2).multiplicationResult == 15)
doAssert(e2.getComponentPtr(MyComponent2).multiplicationResult == 12)
doAssert(e4.getComponentPtr(MyComponent2).multiplicationResult == 10)
```

## Disclaimer
This is still a toy.
