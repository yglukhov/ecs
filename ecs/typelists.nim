import macros

proc newTypeList(): NimNode {.compileTime.} = newNimNode(nnkTupleTy)

iterator typeListTypes(tl: NimNode): NimNode =
    let t = getTypeImpl(getTypeInst(tl)[1])
    for typ in t:
        let i = typ.len - 2
        let r = typ[i]
        for j in 0 ..< i:
            yield copyNimTree(r)

proc addTypeToTypeList(tl: NimNode, typ: NimNode) =
    let ln = tl.len
    tl.add(newNimNode(nnkIdentDefs).add(
        newIdentNode("a" & $ln),
        copyNimTree(typ),
        newEmptyNode()
    ))

macro typeListWithProcArgTypes*(p: typedesc[proc]): untyped =
    let t = getTypeInst(p)
    let prc = t[1]
    let params = prc[0]
    result = newTypeList()
    for i in 1 ..< params.len:
        let typ = params[i][^2]
        for j in 0 ..< params[i].len - 2:
            result.addTypeToTypeList(typ)
    #echo "RES:", treeRepr(result)

macro typeListToTupleType*(tl: typedesc[tuple]): untyped =
    result = newTypeList()
    for typ in typeListTypes(tl):
        case typ.typeKind
        of ntyVar:
            result.addTypeToTypeList(typ[^1])
        else:
            result.addTypeToTypeList(typ)

macro forEachTypeIt*(p: typedesc[tuple], body: untyped): untyped =
    result = newStmtList()
    var i = 0
    for typ in typeListTypes(p):
        let bodyCopy = copyNimTree(body)
        let itIdent = newIdentNode("it")
        let iIdent = newIdentNode("i")
        let blck = quote:
            block:
                type `itIdent` {.used.} = `typ`
                const `iIdent` {.used.} = `i`
                `bodyCopy`
        result.add(blck)
        inc i

macro mutateTypeList*(p: typedesc[tuple], sym: untyped): untyped =
    result = newTypeList()
    for typ in typeListTypes(p):
        let typdesc = newNimNode(nnkBracketExpr).add(
            bindSym"typeDesc",
            typ
        )
        result.addTypeToTypeList(newCall(sym, typdesc))

macro typeListLen*(p: typedesc[tuple]): int =
    let t = getTypeImpl(getTypeInst(p)[1])
    var i = 0
    for identDefs in t:
        inc(i, identDefs.len - 2)
    return newLit(i)

macro appendArgsToCall*(call: untyped, numArgs: static[int], predicate: untyped): untyped =
    result = call
    for i in 0 ..< numArgs:
        call.add(newCall(predicate, newLit(i)))
