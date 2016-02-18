#[

  Synchronized queue implementation

]#

import rlocks, lists, fp.option

{.experimental.}

when not defined(boehmGC):
  {.fatal: "SyncQueue works with boehmgc only!".}

type
  Storage[T] = lists.DoublyLinkedList[T]
  SyncQueue*[T] = ref SyncQueueObj[T]
  SyncQueuePtr*[T] = ptr SyncQueueObj[T]
  SyncQueueObj[T] = object
    lock: RLock
    data {.guard: lock.}: Storage[T]

proc syncQueueFinaizer(q: ref SyncQueueObj) {.nimcall.} =
  q.lock.deinitRLock

proc newSyncQueue*[T](): SyncQueue[T] =
  new(result, syncQueueFinaizer)
  result.lock.initRLock
  withRLock result.lock:
    result.data = initDoublyLinkedList[T]()

converter toPtr*[T](r: ref T): ptr T =
  cast[ptr T](r)

converter toRef*[T](p: ptr T): ref T =
  cast[ref T](p)

proc put*[T](q: SyncQueue[T], v: T) =
  withRLock q.lock:
    q.data.append(v)

proc isEmpty*(q: SyncQueue): bool =
  withRLock q.lock:
    result = q.data.head == nil

proc get*[T](q: SyncQueue[T]): Option[T] =
  withRLock q.lock:
    if q.isEmpty:
      result = T.none
    else:
      let n = q.data.head
      result = n.value.some
      q.data.remove(n)

proc peek*[T](q: SyncQueue[T]): Option[T] =
  withRLock q.lock:
    if q.isEmpty:
      result = T.none
    else:
      let n = q.data.head
      result = n.value.some
