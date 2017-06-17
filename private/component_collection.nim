import types, algorithms

type
    AbstractComponentCollection* = ref object of RootObj
        needsSort*: bool
        entityIds*: seq[EntityId]

    ComponentCollection*[T] = ref object of AbstractComponentCollection
        components*: seq[T]

proc newComponentCollection*[T](): ComponentCollection[T] =
    result.new()
    result.entityIds = @[]
    result.components = @[]

proc addComponent*[T](c: ComponentCollection[T], eid: EntityId, component: T) =
    c.entityIds.add(eid)
    c.components.add(component)
    c.needsSort = true

proc sort[T](c: ComponentCollection[T]) =
    c.needsSort = false

    var entityIds: seq[EntityId]
    shallowCopy(entityIds, c.entityIds)
    var components: seq[T]
    shallowCopy(components, c.components)

    type PivotT = object
        comp: T
        id: EntityId

    type IndexT = int
    template getPivotA(v: var PivotT, a: IndexT) =
        v.comp = components[a]
        v.id = entityIds[a]

    template setPivotA(v: PivotT, a: IndexT) =
        components[a] = v.comp
        entityIds[a] = v.id

    template copyAB(a, b: IndexT) =
        components[a] = components[b]
        entityIds[a] = entityIds[b]

    template geAPivot(a: IndexT, piv: PivotT): bool = entityIds[a] >= piv.id
    template leAPivot(a: IndexT, piv: PivotT): bool = entityIds[a] <= piv.id

    let res = quickSort[PivotT, IndexT](IndexT(0), IndexT(entityIds.high), getPivotA, setPivotA, geAPivot, leAPivot, copyAB)
    doAssert(res)

proc indexOfComponent*[T](c: ComponentCollection[T], eid: EntityId): int32 =
    if c.needsSort: c.sort()
    let m = c.entityIds.high
    result = int32(lowerBoundIt(c.entityIds, 0, m, cmp(it, eid) <= 0) - 1)

proc getComponentPtr*[T](c: ComponentCollection[T], eid: EntityId): ptr T =
    let idx = c.indexOfComponent(eid)
    if idx != -1:
        result = addr c.components[idx]

method prepareForProcessing*(c: AbstractComponentCollection) {.base.} = discard
method prepareForProcessing*[T](c: ComponentCollection[T]) =
    c.sort()

proc reorder*(c: AbstractComponentCollection, order: openarray[EntityId]) =
    var entityIds: seq[EntityId]
    shallowCopy(entityIds, c.entityIds)
    c.needsSort = true
    let ln = entityIds.len
    var i = 0
    while i < ln:
        let e = entityIds[i]
        entityIds[i] = order[e]

proc typeNeedsGC(T: typedesc): bool = true

proc removeComponent*[T](c: ComponentCollection[T], eid: EntityId) =
    let idx = c.indexOfComponent(eid)
    if idx != -1:
        c.entityIds[idx] = -1
        when typeNeedsGC(T):
            var v: T
            c.components[idx] = v

method removeComponentAux*(c: AbstractComponentCollection, eid: EntityId) {.base.} = discard
method removeComponentAux*[T](c: ComponentCollection[T], eid: EntityId) =
    c.removeComponent(eid)
