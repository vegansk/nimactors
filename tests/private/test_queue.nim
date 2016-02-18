import private.queue, unittest, fp.option, threadpool

type
  RefInt = ref object
    v: int

suite "Queue":

  test "Queue singlethreaded":
    let q = newSyncQueue[int]()
    check: q.isEmpty == true
    q.put(1)
    check: q.isEmpty == false
    check: q.peek == 1.some
    check: q.isEmpty == false
    check: q.get == 1.some
    check: q.isEmpty == true

  test "Queue multithreaded":
    let q = newSyncQueue[RefInt]()
    proc test(q: SyncQueuePtr[RefInt]) =
      for x in 1..100:
        var y = new(RefInt)
        y.v = x
        q.put y
    for x in 1..100:
      spawn test(q)
    sync()
    GC_fullCollect()
    while not q.isEmpty:
      echo q.get.get.v
