import unittest,
       actors,
       fp

suite "Actor":

  var actor: Actor[string]
  var actorPtr: ActorPtr[string]

  test "can be created":
    actorPtr = actor.initActor do(self: Actor[string], s: string) -> auto:
      echo s
    actor.setName("stringActor")

  test "can be started":
    check: (start actor).isRight
