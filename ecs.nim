import tables, macros
import variant
import private / [types, algorithms, component_collection]
import typelists

export types

type
  World* = ref object
    entities: seq[Entity]
    componentCollections: seq[AbstractComponentCollection] # Indexed by ComponentId

  Entity* = ref object
    id: EntityId
    world: World

  System*[T: tuple] = ref object of RootObj
    world: World

proc newWorld*(): World =
  result.new()

proc newEntity*(w: World): Entity =
  result.new()
  result.id = EntityId(w.entities.len())
  result.world = w
  w.entities.add(result)

proc init*(s: System, w: World) =
  s.world = w

var componentIds {.compileTime.} = initTable[TypeId, ComponentId]()

proc getComponentId*(T: typedesc): ComponentId {.inline.} =
  const tid = getTypeId(T)
  const componentId = componentIds.mgetOrPut(tid, componentIds.len)
  componentId

{.push checks: off.}
proc getComponentCollection(w: World, compId: ComponentId): AbstractComponentCollection =
  if compId < w.componentCollections.len:
    return w.componentCollections[compId]

proc getComponentCollection*(w: World, T: typedesc): ComponentCollection[T] {.inline.} =
  # private
  type TT = T
  const tid = getComponentId(TT)
  cast[ComponentCollection[T]](w.getComponentCollection(tid))

proc getOrCreateComponentCollectionAux(w: World, compId: ComponentId): AbstractComponentCollection =
  if compId < w.componentCollections.len:
    return w.componentCollections[compId]
  else:
    w.componentCollections.setLen(compId + 1)

proc getOrCreateComponentCollection[T](w: World): ComponentCollection[T] =
  const typId = getComponentId(T)
  var res = w.getOrCreateComponentCollectionAux(typId)
  if res.isNil:
    res = newComponentCollection[T]()
    w.componentCollections[typId] = res
  cast[ComponentCollection[T]](res)
{.pop.}

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
  for c in w.componentCollections:
    if not c.isNil: c.removeComponentAux(eid)

proc addComponent*[T](e: Entity, component: T) {.inline.} =
  e.world.addComponent(e.id, component)

proc getComponentPtr*(e: Entity, T: typedesc): ptr T {.inline.} =
  e.world.getComponentPtr(e.id, T)

proc removeComponent*(e: Entity, T: typedesc) {.inline.} =
  e.world.removeComponent(e.id, T)

proc prepareForProcessing*(w: World) =
  for c in w.componentCollections:
    if not c.isNil and c.needsSort:
      c.prepareForProcessing()

type
  QueryArgFlag = enum
    qaWrite
    qaNot

  QueryArg = object
    typ: NimNode
    name: NimNode
    flags: set[QueryArgFlag]

proc parseArgs(args: openarray[NimNode]): seq[QueryArg] =
  for a in args:
    var qa: QueryArg
    if a.kind == nnkInfix and $a[0] == "as":
      qa.name = a[2]
      qa.name.expectKind(nnkIdent)
      let typ = a[1]
      if typ.kind == nnkVarTy:
        qa.typ = typ[0]
        qa.flags.incl(qaWrite)
      else:
        qa.typ = typ
    else:
      qa.typ = a
    result.add(qa)

type
  Index = uint16

proc rewindToId(ids: openarray[EntityId], id: var EntityId, index: var Index): bool =
  # Set
  let sz = Index(ids.len)
  while index < sz:
    let iId = ids[index]
    if iId == invaliEntityId:
      inc index
      continue
    elif iId == id:
      return true
    elif iId > id:
      id = iId
      return false
    inc index

  id = invaliEntityId

template forEveryMatchingEntityAux(s: System, compTypes: typedesc, body: untyped) =
  block top:
    const compCount = typeListLen(compTypes)

    type
      compPtrsTupleType = typeListMapIt(compTypes, ptr it)
      compSeqsTupleType = typeListMapIt(compTypes, seq[it])

    let world = s.world

    var entityIdSeqs: array[compCount, seq[EntityId]]
    var compSeqs: compSeqsTupleType
    var indexes: array[compCount, uint16]
    var output {.inject.}: compPtrsTupleType

    typeListForEachIt(compTypes):
      let c = world.getComponentCollection(type(it))
      if c.isNil or c.entityIds.len == 0:
        break top
      shallowCopy(entityIdSeqs[iIt], c.entityIds)
      assert((addr entityIdSeqs[iIt][0]) == addr c.entityIds[0], "Am I in global scope?")
      shallowCopy(compSeqs[iIt], c.components)

    var curId = EntityId(0)
    while true:
      typeListForEachIt(compTypes):
        if not rewindToId(entityIdSeqs[iIt], curId, indexes[iIt]):
          if curId == invaliEntityId:
            break top
          else:
            continue

      # echo "indexes: ", indexes

      typeListForEachIt(compTypes):
        output[iIt] = addr compSeqs[iIt][indexes[iIt]]

      `body`

      inc curId

macro forEveryMatchingEntity*(s: System, rawArgs: varargs[untyped]): untyped =
  let body = rawArgs[^1]
  let args = parseArgs(rawArgs[0 .. ^2])
  # TODO: Verify query args against System type

  let argTypes = newNimNode(nnkTupleConstr)
  let aliases = newNimNode(nnkStmtList)
  for i, a in args:
    let typ = a.typ
    argTypes.add(typ)
    if not a.name.isNil:
      let argName = a.name
      let idx = newLit(i)
      aliases.add quote do:
        template `argName`: `typ` =
          output[`idx`][]

  result = quote do:
    forEveryMatchingEntityAux(`s`, `argTypes`):
      `aliases`
      block:
        `body`

proc reorder*(w: World, order: openarray[EntityId]) =
  var entities: seq[Entity]
  shallowCopy(entities, w.entities)
  for i, id in order:
    swap(w.entities[i], w.entities[id])
    w.entities[i].id = id
  for c in w.componentCollections:
    if not c.isNil:
      c.reorder(order)
