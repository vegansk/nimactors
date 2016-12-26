import fp.either

type
  ActorHandler*[T] = proc(msg: T)
  ActorMessage = enum amQuit
  Actor*[T] = object
    ## The actor type. Actors are always typed
    channel: Channel[Either[ActorMessage, T]]
    handler: ActorHandler[T]
  ActorPtr*[T] = ptr Actor[T]

proc initActor*[T](actor: var Actor[T], handler: ActorHandler[T]): ActorPtr[T] {.discardable.} =
  open(actor.channel)
  actor.handler = handler
  actor.addr

proc initActor*[T](handler: ActorHandler[T]): Actor[T] =
  discard initActor(result, handler)

