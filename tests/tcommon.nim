import ../ecs

type
    MyComponent1 = object
        x, y: int
    MyComponent2 = object
        multiplicationResult: int

block:
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

    template runTest(body: untyped) =
        proc test {.genSym.} =
            body
        test()

    var processedEntities = 0

    runTest:
        proc process(c: MyComponent1, res: var MyComponent2) {.inline.} =
            res.multiplicationResult = c.x * c.y
            inc processedEntities

        w.forEveryMatchingEntity(process)

    doAssert(processedEntities == 3)
    doAssert(e1.getComponentPtr(MyComponent2).multiplicationResult == 15)
    doAssert(e2.getComponentPtr(MyComponent2).multiplicationResult == 12)
    doAssert(e4.getComponentPtr(MyComponent2).multiplicationResult == 10)

    processedEntities = 0

    runTest:
        proc process(c: MyComponent1) {.inline.} =
            inc processedEntities
        w.forEveryMatchingEntity(process)

    doAssert(processedEntities == 4)

    e1.removeComponent(MyComponent1)
    e1.removeComponent(MyComponent2)

    processedEntities = 0
    runTest:
        proc process(res: var MyComponent2, c: MyComponent1) {.inline.} =
            inc processedEntities
        w.forEveryMatchingEntity(process)

    doAssert(processedEntities == 2)
