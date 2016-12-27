import unittest,
       nimactors,
       fp,
       boost.richstring,
       boost.types,
       future

suite "Actor":

  var actor: Actor[string, Unit]
  var actorPtr: ActorPtrT(type actor)

  var callsCount = 0
  var checkActor: Actor[string, Unit]
  var checkActorPtr: ActorPtrT(type checkActor)

  test "create":
    actorPtr = actor.initActor do(self: ActorPtr[string, Unit], s: string) -> auto:
      checkActorPtr ! s
      true
    actor.setName("stringActor")

    checkActorPtr = checkActor.initActor do(self: ActorPtr[string, Unit], s: string) -> auto {.gcsafe.}:
      inc callsCount
      if s != fmt"Hello, world #$callsCount!":
        callsCount += 1000
      true

  test "start":
    check: (start checkActor).isRight
    check: (start actor).isRight

  test "handle the messages":
    for x in 1..10:
      check: (actor ! fmt"Hello, world #$x!").isRight

  test "stop":
    check: (stop actor).isRight
    check: (join actor).isRight

  test "check the result":
    check: callsCount == 10
