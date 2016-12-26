import fp,
       boost.types

type
  ActorHandler*[T] = proc(self: ActorPtr[T], msg: T) {.gcsafe.}
  ActorMessage = enum amQuit
  ActorThreadArgs[T] = object
    channel: ptr Channel[Either[ActorMessage, T]]
    handler: ActorHandler[T]
    name: string
  Actor*[T] = ref object
    ## The actor type. Actors are always typed
    channel: Channel[Either[ActorMessage, T]]
    handler: ActorHandler[T]
    name: string
    thread: Thread[ActorThreadArgs[T]]
  ActorPtr*[T] = ptr Actor[T]

proc initActor*[T](actor: var Actor[T], handler: ActorHandler[T]): ActorPtr[T] {.discardable, raises: [].} =
  actor = Actor[T].new
  open(actor.channel)
  actor.handler = handler
  actor.name = ""
  actor.addr

proc initActor*[T](handler: ActorHandler[T]): Actor[T] {.raises: [].} =
  discard initActor(result, handler)

proc setName*[T](a: Actor[T], name: string): Actor[T] {.discardable, raises: [].} =
  a.name = name
  result = a

proc actorThread[T](args: ActorThreadArgs[T]) {.thread, nimcall.} =
  discard

proc start*[T](a: Actor[T]): EitherS[Unit] =
  flatTryS do() -> auto:
    if a.thread.running:
      "The actor is already running".left(Unit)
    else:
      a.thread.createThread(actorThread, ActorThreadArgs[T](channel: a.channel.addr, handler: a.handler))
      ().rightS

proc stop*[T](a: Actor[T]): EitherS[Unit] =
  if not a.thread.running:
    "The actor is not running".left(Unit)
  else:
    tryS do -> auto:
      a.channel.send(amQuit.left(T))
      ()

proc join*[T](a: Actor[T]): EitherS[Unit] =
  if not a.thread.running:
    "The actor is not running".left(Unit)
  else:
    tryS do() -> auto:
      a.thread.joinThread
      ()

proc `!`*[T](a: Actor[T]|ActorPtr[T], msg: T): EitherS[Unit] {.discardable.} =
  if not a.thread.running:
    "The actor is not running".left(Unit)
  else:
    tryS do -> auto:
      a.channel.send(msg.right(ActorMessage))
      ()
