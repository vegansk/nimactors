import unittest,
       actors,
       fp,
       boost.richstring

suite "Actor":

  var actor: Actor[string]
  var actorPtr: ActorPtr[string]

  var callsCount = 0
  var checkActor: Actor[string]
  var checkActorPtr: ActorPtr[string]

  test "create":
    actorPtr = actor.initActor do(self: ActorPtr[string], s: string) -> auto:
      checkActorPtr ! s
      true
    actor.setName("stringActor")

    checkActorPtr = checkActor.initActor do(self: ActorPtr[string], s: string) -> auto:
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
