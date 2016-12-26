import unittest,
       actors

suite "Actor":
  test "can be created":
    var actor: Actor[string]
    let actorPtr: ActorPtr[string] = actor.initActor do(s: string) -> auto:
      echo s
    var actor2 = initActor do(s: string) -> auto:
      echo s
