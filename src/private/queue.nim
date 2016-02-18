#[

  Synchronized queue implementation

]#

import rlocks, lists, fp.option

const useDeepCopy = not defined(boehmGC)

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

when not defined(syncQueueNoCvt):
  converter toPtr*[T](r: ref T): ptr T =
    cast[ptr T](r)

  converter toRef*[T](p: ptr T): ref T =
    cast[ref T](p)

when useDeepCopy:
  proc copy[T](v: T): T =
    when T is object or T is tuple or T is string or T is seq or T is ref or T is array:
      deepCopy result, v
    else:
      v
else:
  template copy(v: untyped): untyped = v

proc put*[T](q: SyncQueue[T], v: T) =
  var v1 = v
  withRLock q.lock:
    q.data.append(copy(v1))

proc isEmpty*(q: SyncQueue): bool =
  withRLock q.lock:
    result = q.data.head == nil

proc get*[T](q: SyncQueue[T]): Option[T] =
  withRLock q.lock:
    if q.isEmpty:
      result = T.none
    else:
      let n = q.data.head
      result = copy(n.value).some
      q.data.remove(n)

proc peek*[T](q: SyncQueue[T]): Option[T] =
  withRLock q.lock:
    if q.isEmpty:
      result = T.none
    else:
      let n = q.data.head
      result = copy(n.value).some
