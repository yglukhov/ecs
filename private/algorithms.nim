
proc cmpx(a, b: int): int = cmp(a, b)

template placePivot[T](arr: var openArray[T], lo, hi: int, cmpAB: untyped, swapAB: untyped): int =
  var pivot = lo #set pivot
  var switch_i = lo + 1
  let x = lo+1

  for i in x..hi: #run on array
    var a {.inject.} = i
    var b {.inject.} = pivot
    if cmpAB <= 0:        #compare pivot and i
      b = switch_i
      swapAB                            #swap(arr[i], arr[switch_i]): swap i and i to switch
      a = pivot
      swapAB                            #swap(arr[pivot], arr[switch_i]): swap pivot and i to switch
      inc pivot    #set current location of pivot
      inc switch_i #set location for i to switch with pivot
  pivot #return pivot location

proc quickSort[T](arr: var openArray[T], lo, hi: int) =
  if lo >= hi: return #stop condition
  #set pivot location
  var pivot = placePivot(arr, lo, hi, cmpx(arr[a], arr[b]), swap(arr[a], arr[b]))
  quickSort(arr, lo, pivot-1) #sort bottom half
  quickSort(arr, pivot+1, hi) #sort top half


template quickSortAB[T](arr: var openArray[T], lo, hi: int, cmpAB: untyped, swapAB: untyped) =
    proc quickSort(arr: var openArray[T], lo, hi: int) =
        if lo >= hi: return #stop condition
        #set pivot location
        var pivot = placePivot(arr, lo, hi, cmpAB, swapAB)
        quickSort(arr, lo, pivot-1) #sort bottom half
        quickSort(arr, pivot+1, hi) #sort top half

    arr.quickSort(lo, hi)

proc quickSort[T](arr: var openarray[T]): bool =

    const MAX_LEVELS = 1000
    var piv: T
    var hi: array[MAX_LEVELS, int]
    var lo: array[MAX_LEVELS, int]
    var i = 0
    var L = 0
    var R = 0

    hi[0] = 0
    lo[0] = arr.len

    while (i >= 0):
        L = hi[i];
        R = lo[i]-1;
        if (L < R):
            piv = arr[L];
            if (i == MAX_LEVELS - 1): return false
            while L < R:
                while (arr[R] >= piv and L < R):
                    dec R
                if (L < R):
                    arr[L] = arr[R];
                    inc L
                while (arr[L] <= piv and L < R):
                    inc L
                if (L < R):
                    arr[R] = arr[L]
                    dec R
            arr[L] = piv;
            hi[i+1] = L+1
            lo[i+1] = lo[i]
            lo[i] = L
            inc i
        else:
            dec i
    return true


template quickSort*[T, IndexT](ilo, ihigh: IndexT,
    getPivotA: untyped, # getPivotA(pivot: var T, a: index)
    setPivotA: untyped, # setPivotA(pivot: T, a: index)
    geAPivot: untyped, # geAPivot(a: index, pivot: T): bool = arr[a] >= pivot
    leAPivot: untyped, # leAPivot(a: index, pivot: T): bool = arr[a] <= pivot
    copyAB: untyped # copyAB(a: index, b: index) # copy from b to a
    ): bool =

    var res = true
    const MAX_LEVELS = 1000
    var piv: T
    var hi {.noInit.}: array[MAX_LEVELS, IndexT]
    var lo {.noInit.}: array[MAX_LEVELS, IndexT]
    var i: IndexT = 0
    var L: IndexT = 0
    var R: IndexT = 0

    hi[0] = ilo
    lo[0] = ihigh + 1

    while (i >= 0):
        L = hi[i];
        R = lo[i]-1;
        if (L < R):
            getPivotA(piv, L)
            if (i == MAX_LEVELS - 1):
                res = false
                break
            while L < R:
                while (geAPivot(R, piv) and L < R):
                    dec R
                if (L < R):
                    copyAB(L, R)
                    inc L
                while (leAPivot(L, piv) and L < R):
                    inc L
                if (L < R):
                    copyAB(R, L)
                    dec R
            setPivotA(piv, L)
            hi[i+1] = L+1
            lo[i+1] = lo[i]
            lo[i] = L
            inc i
        else:
            dec i
    res

proc quickSort1[T](arr: var openarray[T], lo, hi: int): bool =
    type IndexT = int
    template getPivotA(v: var T, a: IndexT) = v = arr[a]
    template setPivotA(v: T, a: IndexT) = arr[a] = v
    template copyAB(a, b: IndexT) = arr[a] = arr[b]
    template geAPivot(a: IndexT, piv: T): bool = arr[a] >= piv
    template leAPivot(a: IndexT, piv: T): bool = arr[a] <= piv 
    quickSort[T, IndexT](IndexT(lo), IndexT(hi), getPivotA, setPivotA, geAPivot, leAPivot, copyAB)


template lowerBoundIt*[T](arr: openarray[T], a, b: int, predicate: untyped): int =
  var result {.gensym.} = a
  var count = b - a + 1
  var step, pos: int
  while count != 0:
    step = count div 2
    pos = result + step
    template it: T {.inject.} = arr[pos]
    if predicate:
      result = pos + 1
      count -= step + 1
    else:
      count = step
  result

when isMainModule:
    import random, times, algorithm

    let length = 100000

    type Foo = distinct int

    var s1 = newSeq[int](length)
    var s2 = newSeq[int](length)

    for i in 0 ..< length:
        let r = random(1000)
        s1[i] = r
        s2[i] = r

    template bench(name: string, body: untyped) =
        echo "Running ", name
        let t1 = epochTime()
        body
        let t2 = epochTime()
        echo "Time: ", t2 - t1

    var success = false
    bench "new":
        success = s2.quickSort1(0, s2.high)

    bench("old"):
        success = s1.quickSort()
#        s1.quickSort(0, s1.high)

    doAssert(success)
    doAssert(isSorted(s1, cmp[int]))
    doAssert(isSorted(s2, cmp[int]))


    # var s = [5, 4, 7, 1, 2, 9]
    # s.quickSort(0, s.high)


    # var s2 = [5, 4, 7, 1, 2, 9]
    # discard s2.quickSort()

    # #s.quickSortAB(0, s.high, cmpx(s[a], s[b]), swap(s[a], s[b]))
    # echo @s
    # echo @s2
