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
    spawn test(q)
    sync()
    for x in 1..100:
      check: q.get.get.v == x
