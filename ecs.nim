import tables, macros
import variant
import private / [types, typelists, algorithms, component_collection]

export types

type
    World* = ref object
        entities: seq[Entity]
        componentCollections: Table[TypeId, AbstractComponentCollection]

    Entity* = ref object
        id: EntityId
        world: World

proc newWorld*(): World =
    result.new()
    result.entities = @[]
    result.componentCollections = initTable[TypeId, AbstractComponentCollection]()

proc newEntity*(w: World): Entity =
    result.new()
    result.id = int32(w.entities.len())
    result.world = w
    w.entities.add(result)

proc getComponentCollection*(w: World, T: typedesc): ComponentCollection[T] =
    # private
    const typId = getTypeId(T)
    result = cast[type(result)](w.componentCollections.getOrDefault(typId))

proc getOrCreateComponentCollection[T](w: World): ComponentCollection[T] =
    const typId = getTypeId(T)
    result = cast[type(result)](w.componentCollections.getOrDefault(typId))
    if result.isNil:
        result = newComponentCollection[T]()
        w.componentCollections[typId] = result

proc addComponent*[T](w: World, eid: EntityId, component: T) =
    getOrCreateComponentCollection[T](w).addComponent(eid, component)

proc getComponentPtr*(w: World, eid: EntityId, T: typedesc): ptr T =
    let c = w.getComponentCollection(T)
    if not c.isNil:
        result = c.getComponentPtr(eid)

proc removeComponent*(w: World, eid: EntityId, T: typedesc) =
    let c = w.getComponentCollection(T)
    if not c.isNil:
        c.removeComponent(eid)

proc removeEntity*(w: World, eid: EntityId) =
    let e = w.entities[eid]
    e.id = invaliEntityId
    e.world = nil
    for c in values(w.componentCollections):
        c.removeComponentAux(eid)

proc addComponent*[T](e: Entity, component: T) {.inline.} =
    e.world.addComponent(e.id, component)

proc getComponentPtr*(e: Entity, T: typedesc): ptr T {.inline.} =
    e.world.getComponentPtr(e.id, T)

proc removeComponent*(e: Entity, T: typedesc) {.inline.} =
    e.world.removeComponent(e.id, T)

proc prepareForProcessing*(w: World) =
    for c in values(w.componentCollections):
        if c.needsSort:
            c.prepareForProcessing()

template forEveryMatchingEntity*(w: World, cb: proc) =
    block top:
        type ttlist = typeListToTupleType(typeListWithProcArgTypes(type(cb)))

        type CompSeq[T] = seq[T]
        template toComponentSeq(TComponent: typedesc): typedesc = CompSeq[TComponent]

        type ttclist = mutateTypeList(ttlist, toComponentSeq)

        const numCollections = typeListLen(ttlist)

        var entityIdsMatrix {.noInit.}: array[numCollections, seq[EntityId]]
        var componentsMatrix {.noInit.}: ttclist
        var collectionLengths {.noInit.}: array[numCollections, int32]
        var indexes: array[numCollections, int32]

        indexes[0] = -1

        forEachTypeIt(ttlist):
            let c {.inject.} = w.getComponentCollection(it)
            if c.isNil: break top

            shallowCopy(entityIdsMatrix[i], c.entityIds)
            shallowCopy(componentsMatrix[i], c.components)
            collectionLengths[i] = int32(c.entityIds.len)

        var curEntityId = 0'i32

        block processingLoop:
            while true:
                forEachTypeIt(ttlist):
                    template iIndex: var int32 = indexes[i]
                    template iEntityIds: seq[EntityId] = entityIdsMatrix[i]
                    template iCollectionLen: int32 = collectionLengths[i]
                    when i == 0:
                        inc iIndex
                        if iIndex == iCollectionLen:
                            break processingLoop
                        curEntityId = iEntityIds[iIndex]
                        if curEntityId == invaliEntityId:
                            continue
                    else:
                        while iIndex < iCollectionLen and
                                (iEntityIds[iIndex] < curEntityId or iEntityIds[iIndex] == invaliEntityId):
                            inc iIndex

                        if iIndex == iCollectionLen:
                            break processingLoop

                        if iEntityIds[iIndex] != curEntityId:
                            continue

                template convertArg(i: int): untyped =
                    componentsMatrix[i][indexes[i]]

                #echo "HIT: ", @indexes
                appendArgsToCall(cb(), numCollections, convertArg)

proc reorder*(w: World, order: openarray[EntityId]) =
    var entities: seq[Entity]
    shallowCopy(entities, w.entities)
    for i, id in order:
        swap(w.entities[i], w.entities[id])
        w.entities[i].id = id
    for c in values(w.componentCollections):
        c.reorder(order)

when isMainModule:
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
