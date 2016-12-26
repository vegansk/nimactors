import unittest,
       actors,
       fp

suite "Actor":

  var actor: Actor[string]
  var actorPtr: ActorPtr[string]

  test "can be created":
    actorPtr = actor.initActor do(self: ActorPtr[string], s: string) -> auto:
      echo s
    actor.setName("stringActor")

  test "can be started":
    check: (start actor).isRight

  test "can receive messages":
    check: (actor ! "Hello, world!").isRight

  test "can be stopped":
    check: (stop actor).isRight
    check: (join actor).isRight
